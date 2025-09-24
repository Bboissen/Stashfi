# API Gateway Code Map (Detailed)

This document explains the structure of `services/api-gateway`, what each file does, key functions, extension points, and operational notes.

## Directory Structure
- `services/api-gateway/`
  - `main.go`
  - `config.go`
  - `middleware.go`
  - `proxy.go`
  - `ratelimit.go`
  - `embed_openapi.go`
  - `openapi_handlers.go`
  - `openapi/public-api.yaml`
  - `openapi/private-api.yaml`
  - `README.md`
  - `Dockerfile`
  - `go.mod`
  - `*_test.go` files

## Files & Responsibilities

### main.go
- Purpose: Program entrypoint, server lifecycle, route registration, internal endpoints, logging/recovery middleware.
- Key types:
  - `Server`: Holds public/private handlers, logger, config, reverse-proxy handlers, transport, rate limiter.
- Important functions:
  - `NewServer()`: Builds logger, loads `Config`, sets transport and rate limiter, registers routes.
  - `setupRoutes()`: Creates two muxes:
    - Public: `/health`, `/ready`, `/api/v1/status`, `/openapi/public.yaml`, proxies `/api/v1/orders/**`.
    - Private: `/health`, `/ready`, `/openapi/private.yaml`, internal API (`/internal/v1/status`, `/internal/v1/echo`), diagnostics (`/metrics`, `/debug/pprof/*`, `/debug/vars`).
  - Middleware in this file:
    - `loggingMiddleware`: Logs method, path, status, duration, remote addr.
    - `recoveryMiddleware`: Catches panics and returns JSON 500.
  - Handlers:
    - Public: `handleHealth`, `handleReady`, `handleAPIStatus`.
    - Private: `handleInternalStatus` (build/runtime/config details), `handleInternalEcho`, `handleMetrics` (minimal Prometheus), plus pprof/expvar.
  - HTTP servers:
    - Public listener on `PORT` (default `8080`).
    - Private listener on `PRIVATE_PORT` (default `8081`).
    - `listenHTTP` helper starts servers; graceful shutdown on SIGINT/SIGTERM.
  - `defaultHTTPTransport()`: Shared transport with sane timeouts, connection pooling, and HTTP/2.
- Extension points:
  - Add new public routes to the public mux in `setupRoutes()`.
  - Add internal-only endpoints to the private mux.
  - Wrap new routes with additional middleware (e.g., auth, rate limiting) as needed.

### config.go
- Purpose: Runtime configuration via environment variables.
- Fields:
  - Upstreams: `OrderServiceURL` (defaults: local `http://localhost:8081`, k8s `http://order-service.stashfi.svc.cluster.local:8080`).
  - Routing: `APIStripPrefix` (default `/api/v1`).
  - HTTP client: `RequestTimeout` (defaults from `REQUEST_TIMEOUT_MS`, 5000ms).
  - Auth: `AuthEnabled` (derived from `AUTH_DISABLE`), `JWTHS256Secret`.
  - Rate limiting: `RateLimitEnabled`, `RateLimitRPS`, `RateLimitBurst`.
- Helpers: `LoadConfig()`, env parsing helpers with defaults.
- Extension: Add per-service URLs, feature toggles, or issuer settings here.

### middleware.go
- Purpose: Cross-cutting middleware (request ID, auth, rate limiting) and small helpers.
- Functions:
  - `requestIDMiddleware`: Ensures and propagates `X-Request-Id`.
  - `withRouteSecurity`: Chains `authMiddleware` and `rateLimitMiddleware` around proxied routes.
  - `rateLimitMiddleware`: Enforces token bucket per client.
  - `authMiddleware`: Optional JWT HS256 validation for Bearer tokens using `validateJWT`.
  - `validateJWT`: Minimal HS256 JWT verify + `exp` check (upgradeable to RS256/JWKS later).
  - `generateRequestID`: Crypto-strong ID fallback to time-based on error.
- Extension: Insert additional checks (scopes/roles), or split public/private auth policies.

### proxy.go
- Purpose: Reverse proxy to upstream services with path rewriting.
- Functions:
  - `proxyTo(targetBase, stripPrefix)`: Builds a `ReverseProxy` with `Director`, headers, timeouts, error handling.
    - Strips `stripPrefix` (e.g., `/api/v1`) from incoming paths.
    - Ensures path starts with `/` and forwards `X-Forwarded-*`, `X-Request-Id`, and `Via: stashfi-gateway` back.
    - Uses `Server.transport` (configurable and testable).
  - Helpers: `clientIP`, `scheme`.
- Extension: Add per-service proxies and compose route groups; add retries/circuit breakers later.

### ratelimit.go
- Purpose: Lightweight, in-memory token-bucket limiter.
- Types:
  - `rateLimiter`: Stores per-client buckets (`sync.Map`).
  - `bucket`: Holds tokens, last refill time, capacity.
- Functions:
  - `newRateLimiter(rps, burst)`, `Allow(key)`.
- Notes: In-memory per-pod; for shared limits use Redis or a Kong plugin.

### embed_openapi.go
- Purpose: `go:embed` public/private OpenAPI specs shipped with the binary for serving at runtime.
- Vars: `openAPIPublicYAML`, `openAPIPrivateYAML`.
- Note: Canonical specs live in `specs/`. Keep embedded copies in sync.

### openapi_handlers.go
- Purpose: Serve embedded OpenAPI files.
- Handlers:
  - `GET /openapi/public.yaml`: returns `openAPIPublicYAML` as `application/yaml`.
  - `GET /openapi/private.yaml`: returns `openAPIPrivateYAML` as `application/yaml`.

### openapi/public-api.yaml & openapi/private-api.yaml
- Purpose: Embedded runtime copies of the OpenAPI specs used for `/openapi/*.yaml` endpoints.
- Public includes `/api/v1/status`, `/api/v1/orders/**` (proxy descriptions).
- Private includes `/internal/v1/status`, `/internal/v1/echo`.

### README.md
- Purpose: Service-level instructions, endpoints, configuration, deployment notes.
- Highlights: Public/private endpoints tables, config env vars, OpenAPI/Spectral linting, docs service.

### Dockerfile
- Purpose: Multi-stage build (Go → Alpine), non-root runtime.
- Notes: Exposes `8080 8081`; pins base packages for reproducibility.

### Tests
- `main_test.go`: Server wiring, `/health`, `/ready`, `/api/v1/status`, `/openapi/public.yaml`, private endpoints (`/internal/v1/status`, `/metrics`, `/debug/pprof/`, `/internal/v1/echo`).
- `orders_proxy_test.go`: Verifies path rewriting for `/api/v1/orders/**` using a fake RoundTripper (no network).
- Running tests locally in sandboxed environments:
  - `cd services/api-gateway && mkdir -p .test-cache && GOCACHE=$(pwd)/.test-cache go test ./...`

## Adding a New Proxied Service Route
1. Config: add a `FOO_SERVICE_URL` (and defaults) in `config.go`.
2. Route: in `setupRoutes()` (public or private), register a handler:
   - `foo := s.withRouteSecurity(s.proxyTo(s.cfg.FooServiceURL, s.cfg.APIStripPrefix))`
   - `pub.Handle("/api/v1/foo", foo)` and `pub.Handle("/api/v1/foo/", foo)`
3. Spec: add public/private OpenAPI entries in `specs/public-api.yaml` and/or `specs/private-api.yaml` with `operationId` and at least one success response.
4. Kong: ensure upstream routing (`/api/v1`) already points to gateway; per-service docs can be added to `/docs` if desired.

## Security & Observability
- Auth: Optional Bearer JWT (HS256). Future upgrade to RS256/JWKS recommended.
- Rate limiting: Optional token bucket per client. For global quotas, offload to gateway plugin or shared store.
- Metrics: Minimal text exposition; replace with `prometheus/client_golang` when ready.
- Debugging: pprof and expvar are private-listener only.

## Operational Defaults
- Timeouts: Server read/write/idle (15s/15s/60s); client transport timeouts set in `defaultHTTPTransport()`.
- Logging: Level/format configurable (`LOG_LEVEL`, `LOG_FORMAT`), request logs include duration and status.
- Graceful shutdown: 30s timeout on SIGINT/SIGTERM.

## Environment Variables (Quick Reference)
- Public listener: `PORT` (default `8080`), `HOST` (default `0.0.0.0`).
- Private listener: `PRIVATE_PORT` (default `8081`).
- Upstreams: `ORDER_SERVICE_URL` (defaults by environment).
- Routing: `API_STRIP_PREFIX` (default `/api/v1`).
- Timeouts: `REQUEST_TIMEOUT_MS` (default `5000`).
- Auth: `AUTH_DISABLE` (`true` to disable), `JWT_HS256_SECRET`.
- Rate limiting: `RATE_LIMIT_ENABLED`, `RATE_LIMIT_RPS` (default `10`), `RATE_LIMIT_BURST` (default `20`).
- Logging: `LOG_LEVEL`, `LOG_FORMAT`, `ENV|GO_ENV|ENVIRONMENT|APP_ENV`, `LOG_SOURCE`.

## Gotchas & Tips
- Embedded specs: Keep `services/api-gateway/openapi/*.yaml` in sync with `specs/*.yaml`.
- Rate limiter scope: In-memory per pod; each replica maintains its own counters.
- Path rewriting: Ensure `APIStripPrefix` matches the public base when proxying (e.g., `/api/v1`).
- Private routes: Never expose the private service via Kong; restrict with NetworkPolicies.
