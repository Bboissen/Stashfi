package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeRoundTripper struct {
	lastReq *http.Request
}

func (f *fakeRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	f.lastReq = r
	body, _ := json.Marshal(map[string]any{"ok": true, "path": r.URL.Path})
	resp := &http.Response{
		StatusCode: http.StatusOK,
		Header:     make(http.Header),
		Body:       io.NopCloser(bytes.NewReader(body)),
		Request:    r,
	}
	resp.Header.Set("Content-Type", "application/json")
	return resp, nil
}

func TestOrderProxy_ForwardsAndStripsPrefix(t *testing.T) {
	t.Setenv("AUTH_DISABLE", "true")
	t.Setenv("RATE_LIMIT_ENABLED", "false")
	t.Setenv("API_STRIP_PREFIX", "/api/v1")

	// Use a fake upstream host to avoid binding listeners in sandbox
	t.Setenv("ORDER_SERVICE_URL", "http://orders.test")
	f := &fakeRoundTripper{}
	server := &Server{logger: setupLogger(), cfg: LoadConfig(), transport: f}
	server.setupRoutes()

	// Request with subpath
	req := httptest.NewRequest("GET", "/api/v1/orders/abc?x=1", nil)
	w := httptest.NewRecorder()
	server.handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d (body: %s)", w.Code, w.Body.String())
	}

	if f.lastReq == nil || f.lastReq.URL.Path != "/orders/abc" {
		got := "<nil>"
		if f.lastReq != nil {
			got = f.lastReq.URL.Path
		}
		t.Fatalf("expected upstream path '/orders/abc', got %q", got)
	}

	if w.Header().Get("X-Request-Id") == "" {
		t.Fatalf("expected X-Request-Id to be set")
	}
}

func TestOrderProxy_ExactPrefix(t *testing.T) {
	t.Setenv("AUTH_DISABLE", "true")
	t.Setenv("RATE_LIMIT_ENABLED", "false")
	t.Setenv("API_STRIP_PREFIX", "/api/v1")

	t.Setenv("ORDER_SERVICE_URL", "http://orders.test")
	f := &fakeRoundTripper{}
	server := &Server{logger: setupLogger(), cfg: LoadConfig(), transport: f}
	server.setupRoutes()

	req := httptest.NewRequest("DELETE", "/api/v1/orders", nil)
	w := httptest.NewRecorder()
	server.handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK { // fake RT returns 200 by default
		t.Fatalf("expected 200, got %d", w.Code)
	}
	if f.lastReq == nil || f.lastReq.URL.Path != "/orders" {
		got := "<nil>"
		if f.lastReq != nil {
			got = f.lastReq.URL.Path
		}
		t.Fatalf("expected upstream path '/orders', got %q", got)
	}
}
