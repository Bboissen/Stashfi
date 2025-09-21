package main

import (
	"encoding/json"
	"log/slog"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

// proxyTo builds a reverse proxy to the given targetBase URL and returns a handler.
// It strips cfg.APIStripPrefix from the incoming request path before forwarding.
func (s *Server) proxyTo(targetBase, stripPrefix string) http.Handler {
	target, err := url.Parse(targetBase)
	if err != nil {
		s.logger.Error("invalid upstream URL", "target", targetBase, "error", err)
		return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			s.respondError(w, http.StatusBadGateway, "Upstream not available")
		})
	}

	proxy := httputil.NewSingleHostReverseProxy(target)
	// Use server-configured transport (overridable in tests)
	proxy.Transport = s.transport

	// Director rewrites the request toward the upstream
	originalDirector := proxy.Director
	proxy.Director = func(r *http.Request) {
		originalDirector(r)

		// Strip the public prefix if present (e.g., /api/v1)
		if stripPrefix != "" && strings.HasPrefix(r.URL.Path, stripPrefix) {
			r.URL.Path = strings.TrimPrefix(r.URL.Path, stripPrefix)
			if r.URL.Path == "" { // ensure at least '/'
				r.URL.Path = "/"
			}
		}

		// Ensure we preserve the path for order endpoints
		// e.g., /api/v1/orders -> /orders
		// If after stripping prefix it doesn't start with '/', add it
		if !strings.HasPrefix(r.URL.Path, "/") {
			r.URL.Path = "/" + r.URL.Path
		}

		// Forward common proxy headers
		r.Header.Set("X-Forwarded-Host", r.Host)
		if xf := r.Header.Get("X-Forwarded-For"); xf == "" {
			r.Header.Set("X-Forwarded-For", clientIP(r))
		}
		r.Header.Set("X-Forwarded-Proto", scheme(r))
		// Forward request id if present (global middleware ensures it)
		if rid := r.Header.Get("X-Request-Id"); rid != "" {
			r.Header.Set("X-Request-Id", rid)
		}

		// Timeouts are enforced by the shared HTTP transport; no per-request context timeout here
	}

	proxy.ModifyResponse = func(resp *http.Response) error {
		// Mark responses as coming via the gateway
		resp.Header.Set("Via", "stashfi-gateway")
		return nil
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		slog.Default().Error("upstream error", "path", r.URL.Path, "error", err)
		// Return a structured JSON error
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"error":   "Upstream error",
			"status":  http.StatusBadGateway,
			"message": err.Error(),
		})
	}

	return proxy
}

func clientIP(r *http.Request) string {
	// Use X-Real-IP or X-Forwarded-For if provided by edge proxy; fallback to RemoteAddr
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}
	if xf := r.Header.Get("X-Forwarded-For"); xf != "" {
		// Take the left-most (client) IP
		if i := strings.Index(xf, ","); i >= 0 {
			return strings.TrimSpace(xf[:i])
		}
		return strings.TrimSpace(xf)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func scheme(r *http.Request) string {
	if r.TLS != nil {
		return "https"
	}
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		return proto
	}
	return "http"
}
