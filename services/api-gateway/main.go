package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
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
	handler http.Handler
	logger  *slog.Logger
}

func NewServer() *Server {
	logger := setupLogger()
	
	// Set as default logger
	slog.SetDefault(logger)

	s := &Server{
		logger: logger,
	}

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
		Level: level,
		AddSource: os.Getenv("LOG_SOURCE") == "true", // Add source file/line info
	}
	
	switch format {
	case "json":
		handler = slog.NewJSONHandler(os.Stdout, opts)
	case "text":
		handler = slog.NewTextHandler(os.Stdout, opts)
	case "pretty":
		// Text handler with more readable output for development
		opts.ReplaceAttr = func(groups []string, a slog.Attr) slog.Attr {
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
	mux := http.NewServeMux()
	
	// Go 1.22+ method-based routing with built-in router
	mux.HandleFunc("GET /health", s.handleHealth())
	mux.HandleFunc("GET /ready", s.handleReady())
	mux.HandleFunc("GET /api/v1/status", s.handleAPIStatus())
	
	// Future routes with path parameters would look like:
	// mux.HandleFunc("GET /api/v1/users/{id}", s.handleGetUser())
	// mux.HandleFunc("POST /api/v1/users", s.handleCreateUser())
	
	// Apply middleware chain
	s.handler = s.loggingMiddleware(s.recoveryMiddleware(mux))
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
	return func(w http.ResponseWriter, r *http.Request) {
		response := HealthResponse{
			Status:    "healthy",
			Timestamp: time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, response)
	}
}

func (s *Server) handleReady() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		response := HealthResponse{
			Status:    "ready",
			Timestamp: time.Now().Unix(),
		}
		s.respondJSON(w, http.StatusOK, response)
	}
}

func (s *Server) handleAPIStatus() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
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
	
	addr := fmt.Sprintf("%s:%s", host, port)
	
	srv := &http.Server{
		Addr:         addr,
		Handler:      server.handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	
	// Log startup configuration
	server.logger.Info("starting API gateway server",
		"address", addr,
		"log_level", os.Getenv("LOG_LEVEL"),
		"log_format", os.Getenv("LOG_FORMAT"),
		"environment", getEnvironmentName())
	
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			server.logger.Error("failed to start server", "error", err)
			os.Exit(1)
		}
	}()
	
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	
	server.logger.Info("shutting down server...")
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if err := srv.Shutdown(ctx); err != nil {
		server.logger.Error("server forced to shutdown", "error", err)
		os.Exit(1)
	}
	
	server.logger.Info("server shutdown complete")
}