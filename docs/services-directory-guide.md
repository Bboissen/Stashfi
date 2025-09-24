# Services Directory Guide

## First Steps
- Install the pinned toolchain: `mise install`
- Run unit tests for the gateway: `go test ./services/api-gateway/...`
- Launch the server locally: `go run ./services/api-gateway`
- Build a container image ready for Kubernetes: `docker build -t stashfi/api-gateway:dev ./services/api-gateway`

## Directory Layout
```
services/
└── api-gateway/
    ├── main.go               # Service entry point & server wiring
    ├── config.go             # Env-driven configuration (upstreams, auth, limits)
    ├── middleware.go         # Recovery, request ID, auth, rate limiting
    ├── proxy.go              # Reverse proxy (orders) with path rewriting
    ├── ratelimit.go          # Token bucket per-client limiter
    ├── main_test.go          # Core handler/middleware tests
    ├── orders_proxy_test.go  # Proxy path rewrite tests
    ├── Dockerfile            # Multi-stage build (Go -> Alpine runtime)
    ├── go.mod / go.sum       # Module metadata (Go 1.25)
    └── README.md             # Service-specific instructions
```

## API Gateway Overview
- **Language/runtime:** Go 1.25 using the standard library HTTP server.
- **Purpose:** Public routing for `/api/v1/**` (including orders proxy) and health/readiness for ops.
- **Features:** Logging, panic recovery, request IDs, optional JWT (HS256) auth, optional rate limiting.
- **Deployment targets:** Raw Kubernetes manifests in `infra/k8s/` and Kong Helm chart (DB-less upstreams).

## Code Walkthrough (`main.go`)
### Configuration & Logging
- Build-time variables `Version`, `BuildTime`, and `GitCommit` can be injected via `go build -ldflags`.
- `setupLogger` selects level (`LOG_LEVEL`) and format (`LOG_FORMAT`) with sensible defaults (`pretty` text locally, JSON in production) using Go’s `slog` package.
- `getEnvironmentName` resolves `ENV`, `GO_ENV`, `ENVIRONMENT`, or `APP_ENV`, falling back to `development` unless the code is running in Kubernetes.

### HTTP Server Setup
- Routes are registered with the Go 1.22 method-aware `ServeMux`:
  - `GET /health` → `handleHealth`
  - `GET /ready` → `handleReady`
  - `GET /api/v1/status` → `handleAPIStatus`
  - `ANY /api/v1/orders[/**]` → reverse proxy to the Order service
- Middleware stack: `recovery` → `requestID` → `logging`; proxied routes add `rate limit` and `auth` when enabled.

### Handlers & Responses
- `HealthResponse` and `APIStatusResponse` structs produce JSON payloads with unix timestamps.
- `handleHealth` / `handleReady` return the current status (`healthy`/`ready`).
- `handleAPIStatus` reports service name, hard-coded semantic version (`0.1.0`), and operational state.
- `respondJSON` and `respondError` centralize JSON encoding and error responses.

### Lifecycle Management
- Command-line flags `--version` and `--help` provide quick introspection without running the server.
- Environment variables `PORT` and `HOST` override defaults (`8080`, `0.0.0.0`).
- The HTTP server sets read/write/idle timeouts (15 s / 15 s / 60 s) and supports graceful shutdown with a 30 s timeout when SIGINT or SIGTERM is caught.

## Testing
- `main_test.go`: server wiring and core endpoints.
- `orders_proxy_test.go`: ensures `/api/v1/orders/**` rewrites to `/orders/**` upstream; uses a mock transport.

## Container Image (`Dockerfile`)
1. **Builder stage:** `golang:1.25-alpine3.22`, pins `git` and downloads modules before compiling a static binary (`CGO_ENABLED=0`).
2. **Runtime stage:** `alpine:3.22`, installs `ca-certificates=20250619-r0`, creates non-root user `appuser` (`uid=1000`), and copies the binary with correct ownership.

Run the image locally:
```bash
docker run --rm -p 8080:8080 -e LOG_LEVEL=DEBUG stashfi/api-gateway:dev
```

## Integration Points
- **Helm/Kong:** `infra/helm/kong/values.yaml` routes `/health`, `/ready`, and `/api/v1` to the ClusterIP service `api-gateway-service`.
- **Kubernetes manifests:** `infra/k8s/api-gateway-deployment.yaml` & `api-gateway-service.yaml` deploy the gateway.
- **OpenAPI:** Public spec in `specs/public-api.yaml`; lint with Spectral (`.spectral.yaml`).

Keep this guide updated when adding routes, middleware, configuration options, or additional services under `services/`.
