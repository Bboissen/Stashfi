package main

import (
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds runtime configuration for the gateway.
type Config struct {
	// Upstreams
	OrderServiceURL string

	// Routing
	APIStripPrefix string // strip this prefix before proxying (e.g., "/api/v1")

	// HTTP client
	RequestTimeout time.Duration

	// Auth
	AuthEnabled    bool
	JWTHS256Secret string

	// Rate limiting
	RateLimitEnabled bool
	RateLimitRPS     float64
	RateLimitBurst   int
}

func LoadConfig() Config {
	cfg := Config{}

	// Upstreams with sensible defaults for local vs k8s
	cfg.OrderServiceURL = getenv("ORDER_SERVICE_URL", defaultOrderServiceURL())

	// Routing
	cfg.APIStripPrefix = getenv("API_STRIP_PREFIX", "/api/v1")

	// HTTP client timeout
	timeoutMs := getenv("REQUEST_TIMEOUT_MS", "5000")
	if v, err := strconv.Atoi(timeoutMs); err == nil && v > 0 {
		cfg.RequestTimeout = time.Duration(v) * time.Millisecond
	} else {
		cfg.RequestTimeout = 5 * time.Second
	}

	// Auth
	authDisabled := strings.EqualFold(os.Getenv("AUTH_DISABLE"), "true")
	cfg.AuthEnabled = !authDisabled
	cfg.JWTHS256Secret = os.Getenv("JWT_HS256_SECRET")

	// Rate limiting
	cfg.RateLimitEnabled = strings.EqualFold(os.Getenv("RATE_LIMIT_ENABLED"), "true")
	cfg.RateLimitRPS = parseFloatEnv("RATE_LIMIT_RPS", 10.0)
	cfg.RateLimitBurst = parseIntEnv("RATE_LIMIT_BURST", 20)

	return cfg
}

func defaultOrderServiceURL() string {
	// Prefer cluster DNS when running in k8s
	if os.Getenv("KUBERNETES_SERVICE_HOST") != "" {
		return "http://order-service.stashfi.svc.cluster.local:8080"
	}
	// Local dev
	return "http://localhost:8081"
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func parseFloatEnv(key string, def float64) float64 {
	if v := os.Getenv(key); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

func parseIntEnv(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return def
}
