package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"
)

// requestIDMiddleware ensures every request has an X-Request-Id and echoes it back in the response.
func (s *Server) requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rid := r.Header.Get("X-Request-Id")
		if rid == "" {
			rid = generateRequestID()
			r.Header.Set("X-Request-Id", rid)
		}
		// Ensure response carries the request id
		w.Header().Set("X-Request-Id", rid)
		next.ServeHTTP(w, r)
	})
}

// withRouteSecurity applies per-route security chain (rate limiting and auth) around a handler.
func (s *Server) withRouteSecurity(next http.Handler) http.Handler {
	h := next
	// Auth after rate limiting (save crypto work on abusive traffic)
	h = s.authMiddleware(h)
	h = s.rateLimitMiddleware(h)
	return h
}

func (s *Server) rateLimitMiddleware(next http.Handler) http.Handler {
	// Disabled
	if s.rl == nil || !s.cfg.RateLimitEnabled {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		client := clientKey(r)
		if !s.rl.Allow(client) {
			s.respondError(w, http.StatusTooManyRequests, "rate limit exceeded")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) authMiddleware(next http.Handler) http.Handler {
	if !s.cfg.AuthEnabled {
		return next
	}
	// Require Bearer token (JWT HS256)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authz := r.Header.Get("Authorization")
		if authz == "" {
			s.respondError(w, http.StatusUnauthorized, "missing Authorization header")
			return
		}
		parts := strings.SplitN(authz, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			s.respondError(w, http.StatusUnauthorized, "invalid Authorization header")
			return
		}
		if s.cfg.JWTHS256Secret == "" {
			s.respondError(w, http.StatusUnauthorized, "auth not configured")
			return
		}
		if _, err := validateJWT(parts[1], s.cfg.JWTHS256Secret); err != nil {
			s.respondError(w, http.StatusUnauthorized, "invalid token")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func clientKey(r *http.Request) string {
	// Prefer X-Forwarded-For left-most entry
	if xf := r.Header.Get("X-Forwarded-For"); xf != "" {
		if i := strings.Index(xf, ","); i >= 0 {
			return strings.TrimSpace(xf[:i])
		}
		return strings.TrimSpace(xf)
	}
	// Fallback to RemoteAddr
	return strings.TrimSpace(r.RemoteAddr)
}

func generateRequestID() string {
	b := make([]byte, 16)
	// crypto/rand already imported indirectly elsewhere; use stdlib here
	if _, err := randRead(b); err != nil {
		// Fallback to time-based value
		return hex.EncodeToString([]byte(time.Now().Format("20060102150405.000000000")))
	}
	return hex.EncodeToString(b)
}

// indirection for ease of testing/mocking (referencing function directly avoids lint warning)
var randRead = rand.Read

// validateJWT validates a HS256-signed JWT and returns claims if valid.
func validateJWT(token, secret string) (map[string]any, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid token format")
	}
	headerJSON, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, err
	}
	payloadJSON, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, err
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, err
	}

	var header map[string]any
	if err := json.Unmarshal(headerJSON, &header); err != nil {
		return nil, err
	}
	if alg, _ := header["alg"].(string); !strings.EqualFold(alg, "HS256") {
		return nil, errors.New("unsupported alg")
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(parts[0]))
	mac.Write([]byte("."))
	mac.Write([]byte(parts[1]))
	if !hmac.Equal(mac.Sum(nil), sig) {
		return nil, errors.New("signature mismatch")
	}

	var claims map[string]any
	if err := json.Unmarshal(payloadJSON, &claims); err != nil {
		return nil, err
	}
	// Optional exp check
	if expVal, ok := claims["exp"]; ok {
		switch v := expVal.(type) {
		case float64:
			if int64(v) < time.Now().Unix() {
				return nil, errors.New("token expired")
			}
		case json.Number:
			if i, err := v.Int64(); err == nil && i < time.Now().Unix() {
				return nil, errors.New("token expired")
			}
		}
	}
	return claims, nil
}
