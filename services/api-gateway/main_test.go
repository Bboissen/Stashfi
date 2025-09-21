package main

import (
    "net/http"
    "net/http/httptest"
    "testing"
    "strings"
)

func TestNewServer(t *testing.T) {
	server := NewServer()
	if server == nil {
		t.Fatal("NewServer() returned nil")
	}
	if server.handler == nil {
		t.Fatal("Server handler is nil")
	}
	if server.logger == nil {
		t.Fatal("Server logger is nil")
	}
}

func TestHealthEndpoint(t *testing.T) {
	server := NewServer()

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	server.handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("Expected Content-Type application/json, got %s", contentType)
	}
}

func TestReadyEndpoint(t *testing.T) {
	server := NewServer()

	req := httptest.NewRequest("GET", "/ready", nil)
	w := httptest.NewRecorder()

	server.handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, w.Code)
	}
}

func TestAPIStatusEndpoint(t *testing.T) {
    server := NewServer()

	req := httptest.NewRequest("GET", "/api/v1/status", nil)
	w := httptest.NewRecorder()

	server.handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, w.Code)
	}
}

func TestOpenAPIPublicYAMLEndpoint(t *testing.T) {
    server := NewServer()
    req := httptest.NewRequest("GET", "/openapi/public.yaml", nil)
    w := httptest.NewRecorder()
    server.handler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d", w.Code)
    }
    if ct := w.Header().Get("Content-Type"); ct == "" {
        t.Fatalf("expected content-type, got empty")
    }
}

func TestPrivateStatusEndpoint(t *testing.T) {
    server := NewServer()
    req := httptest.NewRequest("GET", "/internal/v1/status", nil)
    w := httptest.NewRecorder()
    server.privateHandler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d", w.Code)
    }
    if ct := w.Header().Get("Content-Type"); ct != "application/json" {
        t.Fatalf("expected application/json, got %s", ct)
    }
}

func TestPrivateMetrics(t *testing.T) {
    server := NewServer()
    req := httptest.NewRequest("GET", "/metrics", nil)
    w := httptest.NewRecorder()
    server.privateHandler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d", w.Code)
    }
    if ct := w.Header().Get("Content-Type"); ct == "" {
        t.Fatalf("expected content type, got empty")
    }
    if !strings.Contains(w.Body.String(), "process_uptime_seconds") {
        t.Fatalf("expected metrics to contain process_uptime_seconds")
    }
}

func TestPrivatePprofIndex(t *testing.T) {
    server := NewServer()
    req := httptest.NewRequest("GET", "/debug/pprof/", nil)
    w := httptest.NewRecorder()
    server.privateHandler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d", w.Code)
    }
}

func TestPrivateEcho(t *testing.T) {
    server := NewServer()
    req := httptest.NewRequest("POST", "/internal/v1/echo", strings.NewReader("hello"))
    req.Header.Set("X-Test", "1")
    w := httptest.NewRecorder()
    server.privateHandler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d", w.Code)
    }
}

func TestGetLogLevel(t *testing.T) {
	// Test default behavior
	level := getLogLevel()
	if level.String() == "" {
		t.Error("getLogLevel() returned empty string")
	}
}

func TestGetEnvironmentName(t *testing.T) {
	// Test default behavior
	env := getEnvironmentName()
	if env == "" {
		t.Error("getEnvironmentName() returned empty string")
	}
}

func TestIsProduction(t *testing.T) {
	// Test default behavior - should return false in test environment
	isProd := isProduction()
	if isProd {
		t.Error("isProduction() should return false in test environment")
	}
}

func TestRecoveryMiddleware(t *testing.T) {
	server := NewServer()

	// Create a handler that panics
	panicHandler := http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		panic("test panic")
	})

	// Wrap it with recovery middleware
	recoveryWrapped := server.recoveryMiddleware(panicHandler)

	req := httptest.NewRequest("GET", "/panic", nil)
	w := httptest.NewRecorder()

	// This should not panic, but return 500
	recoveryWrapped.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("Expected status %d after panic, got %d", http.StatusInternalServerError, w.Code)
	}
}

func TestRespondError(t *testing.T) {
	server := NewServer()
	w := httptest.NewRecorder()

	server.respondError(w, http.StatusBadRequest, "test error")

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("Expected Content-Type application/json, got %s", contentType)
	}
}
