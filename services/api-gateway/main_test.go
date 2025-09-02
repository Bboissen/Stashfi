package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
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
