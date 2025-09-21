// Package main implements the Stashfi API Gateway service.
package main

import (
    "context"
    "encoding/json"
    "expvar"
    "flag"
    "fmt"
    "errors"
    "io"
    "log/slog"
    "net"
    "net/http"
    "net/http/pprof"
    "os"
    "os/signal"
    "runtime"
    "strconv"
    "strings"
    "syscall"
    "time"
)

const (
	defaultPort = "8080"
	defaultHost = "0.0.0.0"
)

var (
	// Version information (set at build time)
	Version   = "dev"
	BuildTime = "unknown"
	GitCommit = "unknown"
)

type Server struct {
	handler        http.Handler // public handler (for back-compat in tests/CLI)
	publicHandler  http.Handler
	privateHandler http.Handler
	logger         *slog.Logger
	cfg            Config
	rl             *rateLimiter
	orders         http.Handler // reverse proxy to order service with per-route middleware
	transport      http.RoundTripper
}

func NewServer() *Server {
	logger := setupLogger()

	// Set as default logger
	slog.SetDefault(logger)

	cfg := LoadConfig()

	s := &Server{
		logger: logger,
		cfg:    cfg,
	}

	if cfg.RateLimitEnabled {
		s.rl = newRateLimiter(cfg.RateLimitRPS, cfg.RateLimitBurst)
	}
	// default transport with sane timeouts
	s.transport = defaultHTTPTransport()

	s.setupRoutes()
	return s
}

// setupLogger configures logging based on environment variables
func setupLogger() *slog.Logger {
	// Determine log level from multiple sources (in order of precedence)
	// 1. LOG_LEVEL env var
	// 2. Based on environment (ENV/GO_ENV/ENVIRONMENT)
	// 3. Default to INFO
	level := getLogLevel()

	// Determine output format
	// LOG_FORMAT can be: json, text, or pretty (default based on environment)
	format := getLogFormat()

	var handler slog.Handler
	opts := &slog.HandlerOptions{
		Level:     level,
		AddSource: os.Getenv("LOG_SOURCE") == "true", // Add source file/line info
	}

	switch format {
	case "json":
		handler = slog.NewJSONHandler(os.Stdout, opts)
	case "text":
		handler = slog.NewTextHandler(os.Stdout, opts)
	case "pretty":
		// Text handler with more readable output for development
		opts.ReplaceAttr = func(_ []string, a slog.Attr) slog.Attr {
			// Customize timestamp format for better readability
			if a.Key == slog.TimeKey {
				return slog.String("time", a.Value.Time().Format("15:04:05.000"))
			}
			return a
		}
		handler = slog.NewTextHandler(os.Stdout, opts)
	default:
		// Auto-detect based on environment
		if isProduction() {
			handler = slog.NewJSONHandler(os.Stdout, opts)
		} else {
			handler = slog.NewTextHandler(os.Stdout, opts)
		}
	}

	return slog.New(handler)
}

// getLogLevel determines the appropriate log level from environment
func getLogLevel() slog.Level {
	// Check LOG_LEVEL first (standard)
	levelStr := os.Getenv("LOG_LEVEL")
	if levelStr == "" {
		// Fallback to environment-based defaults
		if isProduction() {
			levelStr = "INFO"
		} else {
			levelStr = "DEBUG"
		}
	}

	// Parse level string
	switch strings.ToUpper(levelStr) {
	case "DEBUG":
		return slog.LevelDebug
	case "INFO":
		return slog.LevelInfo
	case "WARN", "WARNING":
		return slog.LevelWarn
	case "ERROR":
		return slog.LevelError
	default:
		// Default to INFO for unknown values
		return slog.LevelInfo
	}
}

// getLogFormat determines the log output format
func getLogFormat() string {
	format := os.Getenv("LOG_FORMAT")
	if format != "" {
		return strings.ToLower(format)
	}

	// Auto-detect based on environment
	if isProduction() {
		return "json"
	}
	return "pretty"
}

// getEnvironmentName returns the current environment name
func getEnvironmentName() string {
	// Check multiple standard environment variables
	env := os.Getenv("ENV")
	if env == "" {
		env = os.Getenv("GO_ENV")
	}
	if env == "" {
		env = os.Getenv("ENVIRONMENT")
	}
	if env == "" {
		env = os.Getenv("APP_ENV")
	}
	if env == "" {
		// Default based on Kubernetes detection
		if os.Getenv("KUBERNETES_SERVICE_HOST") != "" {
			return "kubernetes"
		}
		return "development"
	}
	return env
}

// isProduction checks multiple environment indicators
func isProduction() bool {
	env := getEnvironmentName()
	// Consider it production if explicitly set to production/prod
	// or if running in Kubernetes (detected by service account)
	return strings.HasPrefix(strings.ToLower(env), "prod") ||
		env == "production" ||
		os.Getenv("KUBERNETES_SERVICE_HOST") != ""
}

func (s *Server) setupRoutes() {
	// Public mux
	pub := http.NewServeMux()
	pub.HandleFunc("GET /health", s.handleHealth())
	pub.HandleFunc("GET /ready", s.handleReady())
	pub.HandleFunc("GET /api/v1/status", s.handleAPIStatus())
	// Serve OpenAPI spec (public)
	pub.HandleFunc("GET /openapi/public.yaml", s.handleOpenAPIPublic())

	// Reverse proxy routes for the Order service
	s.orders = s.withRouteSecurity(s.proxyTo(s.cfg.OrderServiceURL, s.cfg.APIStripPrefix))
	pub.Handle("/api/v1/orders", s.orders)
	pub.Handle("/api/v1/orders/", s.orders)

	// Future routes with path parameters would look like:
	// pub.HandleFunc("GET /api/v1/users/{id}", s.handleGetUser())
	// pub.HandleFunc("POST /api/v1/users", s.handleCreateUser())

	// Private mux (internal endpoints)
	priv := http.NewServeMux()
	priv.HandleFunc("GET /health", s.handleHealth())
	priv.HandleFunc("GET /ready", s.handleReady())
	// Private OpenAPI spec
	priv.HandleFunc("GET /openapi/private.yaml", s.handleOpenAPIPrivate())
	// Internal API group
	priv.HandleFunc("GET /internal/v1/status", s.handleInternalStatus())
	priv.HandleFunc("POST /internal/v1/echo", s.handleInternalEcho())
	// Debug/metrics endpoints (standard internal routes)
	priv.Handle("/debug/vars", expvar.Handler())
	// pprof endpoints
	priv.HandleFunc("/debug/pprof/", pprof.Index)
	priv.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	priv.HandleFunc("/debug/pprof/profile", pprof.Profile)
	priv.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	priv.HandleFunc("/debug/pprof/trace", pprof.Trace)
	priv.Handle("/debug/pprof/allocs", pprof.Handler("allocs"))
	priv.Handle("/debug/pprof/block", pprof.Handler("block"))
	priv.Handle("/debug/pprof/goroutine", pprof.Handler("goroutine"))
	priv.Handle("/debug/pprof/heap", pprof.Handler("heap"))
	priv.Handle("/debug/pprof/mutex", pprof.Handler("mutex"))
	priv.Handle("/debug/pprof/threadcreate", pprof.Handler("threadcreate"))
	// Minimal Prometheus-style metrics
	priv.HandleFunc("GET /metrics", s.handleMetrics())

	// Apply middleware chains
	chain := func(h http.Handler) http.Handler {
		return s.loggingMiddleware(s.requestIDMiddleware(s.recoveryMiddleware(h)))
	}
	s.publicHandler = chain(pub)
	s.privateHandler = chain(priv)
	s.handler = s.publicHandler
}

var startTime = time.Now()

func (s *Server) handleInternalStatus() http.HandlerFunc {
	type resp struct {
		Service          string `json:"service"`
		Version          string `json:"version"`
		BuildTime        string `json:"build_time"`
		GitCommit        string `json:"git_commit"`
		Environment      string `json:"environment"`
		UptimeSeconds    int64  `json:"uptime_seconds"`
		GoVersion        string `json:"go_version"`
		Goroutines       int    `json:"goroutines"`
		NumCPU           int    `json:"num_cpu"`
		RateLimitEnabled bool   `json:"rate_limit_enabled"`
		AuthEnabled      bool   `json:"auth_enabled"`
		OrderServiceURL  string `json:"order_service_url"`
		RequestTimeoutMS int64  `json:"request_timeout_ms"`
		Timestamp        int64  `json:"timestamp"`
	}
	return func(w http.ResponseWriter, _ *http.Request) {
		r := resp{
			Service:          "api-gateway",
			Version:          Version,
			BuildTime:        BuildTime,
			GitCommit:        GitCommit,
			Environment:      getEnvironmentName(),
			UptimeSeconds:    int64(time.Since(startTime).Seconds()),
			GoVersion:        runtime.Version(),
			Goroutines:       runtime.NumGoroutine(),
			NumCPU:           runtime.NumCPU(),
			RateLimitEnabled: s.cfg.RateLimitEnabled,
			AuthEnabled:      s.cfg.AuthEnabled,
			OrderServiceURL:  s.cfg.OrderServiceURL,
			RequestTimeoutMS: int64(s.cfg.RequestTimeout / time.Millisecond),
			Timestamp:        time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, r)
	}
}

func (s *Server) handleInternalEcho() http.HandlerFunc {
	type echoResp struct {
		Headers map[string]string `json:"headers"`
		Body    string            `json:"body"`
		Method  string            `json:"method"`
		Path    string            `json:"path"`
	}
	return func(w http.ResponseWriter, r *http.Request) {
		// Limit body to avoid abuse
		r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB
		b, _ := io.ReadAll(r.Body)
		headers := make(map[string]string, len(r.Header))
		for k, v := range r.Header {
			headers[k] = strings.Join(v, ",")
		}
		s.respondJSON(w, http.StatusOK, echoResp{
			Headers: headers,
			Body:    string(b),
			Method:  r.Method,
			Path:    r.URL.Path,
		})
	}
}

func (s *Server) handleMetrics() http.HandlerFunc {
	// Minimal text exposition for Prometheus scraping
	// For full metrics, integrate prometheus/client_golang in the future.
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		now := time.Now()
		lines := []string{
			"# HELP process_uptime_seconds Process uptime in seconds.",
			"# TYPE process_uptime_seconds gauge",
			"process_uptime_seconds " + strconv.FormatFloat(time.Since(startTime).Seconds(), 'f', 3, 64),
			"# HELP go_goroutines Number of goroutines.",
			"# TYPE go_goroutines gauge",
			"go_goroutines " + strconv.Itoa(runtime.NumGoroutine()),
			"# HELP app_info Build and configuration info.",
			"# TYPE app_info gauge",
			fmt.Sprintf("app_info{version=\"%s\",git_commit=\"%s\",environment=\"%s\"} 1", Version, GitCommit, getEnvironmentName()),
			"# HELP scrape_timestamp_seconds Unix timestamp of this scrape.",
			"# TYPE scrape_timestamp_seconds gauge",
			fmt.Sprintf("scrape_timestamp_seconds %d", now.Unix()),
		}
		for i := range lines {
			_, _ = w.Write([]byte(lines[i]))
			_, _ = w.Write([]byte{'\n'})
		}
	}
}

func defaultHTTPTransport() http.RoundTripper {
	return &http.Transport{
		Proxy:                 http.ProxyFromEnvironment,
		DialContext:           (&net.Dialer{Timeout: 5 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   5 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}
}

func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		wrapped := &responseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(wrapped, r)

		s.logger.Info("request completed",
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
			"status", wrapped.statusCode,
			"duration", time.Since(start))
	})
}

func (s *Server) recoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				s.logger.Error("panic recovered",
					"error", err,
					"path", r.URL.Path)

				// Use proper JSON error response
				s.respondError(w, http.StatusInternalServerError, "Internal Server Error")
			}
		}()

		next.ServeHTTP(w, r)
	})
}

// Response types for proper JSON encoding
type HealthResponse struct {
	Status    string `json:"status"`
	Timestamp int64  `json:"timestamp"`
}

type APIStatusResponse struct {
	Service   string `json:"service"`
	Version   string `json:"version"`
	Status    string `json:"status"`
	Timestamp int64  `json:"timestamp"`
}

func (s *Server) handleHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		response := HealthResponse{
			Status:    "healthy",
			Timestamp: time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, response)
	}
}

func (s *Server) handleReady() http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		response := HealthResponse{
			Status:    "ready",
			Timestamp: time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, response)
	}
}

func (s *Server) handleAPIStatus() http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		response := APIStatusResponse{
			Service:   "api-gateway",
			Version:   "0.1.0",
			Status:    "operational",
			Timestamp: time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, response)
	}
}

// Helper method for JSON responses
func (s *Server) respondJSON(w http.ResponseWriter, statusCode int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	if err := json.NewEncoder(w).Encode(data); err != nil {
		s.logger.Error("failed to encode JSON response", "error", err)
	}
}

// Helper method for JSON error responses
func (s *Server) respondError(w http.ResponseWriter, statusCode int, message string) {
	errorResponse := struct {
		Error     string `json:"error"`
		Status    int    `json:"status"`
		Timestamp int64  `json:"timestamp"`
	}{
		Error:     message,
		Status:    statusCode,
		Timestamp: time.Now().Unix(),
	}
	s.respondJSON(w, statusCode, errorResponse)
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func main() {
	// Parse command-line flags
	var (
		versionFlag = flag.Bool("version", false, "Print version information")
		helpFlag    = flag.Bool("help", false, "Print help information")
	)
	flag.Parse()

	// Handle version flag
	if *versionFlag {
		fmt.Printf("api-gateway version %s\n", Version)
		fmt.Printf("Build time: %s\n", BuildTime)
		fmt.Printf("Git commit: %s\n", GitCommit)
		os.Exit(0)
	}

	// Handle help flag
	if *helpFlag {
		fmt.Println("Stashfi API Gateway")
		fmt.Println("\nUsage:")
		fmt.Println("  api-gateway [flags]")
		fmt.Println("\nFlags:")
		fmt.Println("  --help      Show this help message")
		fmt.Println("  --version   Show version information")
		fmt.Println("\nEnvironment Variables:")
		fmt.Println("  PORT        Server port (default: 8080)")
		fmt.Println("  HOST        Server host (default: 0.0.0.0)")
		fmt.Println("  LOG_LEVEL   Log level (DEBUG, INFO, WARN, ERROR)")
		fmt.Println("  LOG_FORMAT  Log format (json, text, pretty)")
		fmt.Println("  ENV         Environment (production, development)")
		os.Exit(0)
	}

	server := NewServer()

	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	host := os.Getenv("HOST")
	if host == "" {
		host = defaultHost
	}

	// Private listener port
	privatePort := os.Getenv("PRIVATE_PORT")
	if privatePort == "" {
		privatePort = "8081"
	}

	publicAddr := fmt.Sprintf("%s:%s", host, port)
	privateAddr := fmt.Sprintf("%s:%s", host, privatePort)

	pubSrv := &http.Server{
		Addr:         publicAddr,
		Handler:      server.publicHandler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	privSrv := &http.Server{
		Addr:         privateAddr,
		Handler:      server.privateHandler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Log startup configuration
	server.logger.Info("starting API gateway servers",
		"public", publicAddr,
		"private", privateAddr,
		"log_level", os.Getenv("LOG_LEVEL"),
		"log_format", os.Getenv("LOG_FORMAT"),
		"environment", getEnvironmentName(),
		"order_service", server.cfg.OrderServiceURL)

	errCh := make(chan error, 2)
	go func() { errCh <- listenHTTP(pubSrv) }()
	go func() { errCh <- listenHTTP(privSrv) }()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-quit:
		server.logger.Info("shutdown signal received", "signal", sig.String())
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			server.logger.Error("server error", "error", err)
		}
	}

	server.logger.Info("shutting down servers...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_ = pubSrv.Shutdown(ctx)
	_ = privSrv.Shutdown(ctx)
	server.logger.Info("shutdown complete")
}

func listenHTTP(srv *http.Server) error {
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}
