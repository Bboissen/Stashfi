package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const (
	defaultPort = "8080"
	defaultHost = "0.0.0.0"
)

type Server struct {
	handler http.Handler
	logger  *slog.Logger
}

func NewServer() *Server {
	var logger *slog.Logger
	
	if os.Getenv("ENV") == "production" {
		// JSON output for production
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelInfo,
		}))
	} else {
		// Text output for development with colors
		logger = slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelDebug,
		}))
	}
	
	// Set as default logger
	slog.SetDefault(logger)

	s := &Server{
		logger: logger,
	}

	s.setupRoutes()
	return s
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
				
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()
		
		next.ServeHTTP(w, r)
	})
}

func (s *Server) handleHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"status":"healthy","timestamp":%d}`, time.Now().Unix())
	}
}

func (s *Server) handleReady() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"status":"ready","timestamp":%d}`, time.Now().Unix())
	}
}

func (s *Server) handleAPIStatus() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"service":"api-gateway","version":"0.1.0","status":"operational","timestamp":%d}`, time.Now().Unix())
	}
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
	
	server.logger.Info("starting API gateway server",
		"address", addr)
	
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