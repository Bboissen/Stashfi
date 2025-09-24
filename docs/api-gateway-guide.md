# API Gateway – Current State (Junior Guide)

This guide explains the API Gateway in simple terms so you can understand how it works today and how to extend it.

## What It Does
- Sits in front of backend services and exposes a single HTTP entrypoint.
- Terminates client requests and forwards (proxies) them to the right service.
- Adds cross‑cutting features: logging, request IDs, optional auth, and optional rate limiting.

Public vs Private APIs
- Public: consumer-facing endpoints under `/api/v1/**` (documented in `specs/public-api.yaml`).
- Private: internal endpoints under `/internal/v1/**` (to be added; placeholder spec at `specs/private-api.yaml`).

## Tech Stack
- Language: Go (standard library only)
- Router: Go 1.22+ `http.ServeMux` with method-based patterns
- Reverse proxy: `net/http/httputil.ReverseProxy`
- Logging: `log/slog`

## Current Endpoints
- `GET /health` – Liveness check
- `GET /ready` – Readiness check
- `GET /api/v1/status` – Gateway status info
- `ANY /api/v1/orders` and `ANY /api/v1/orders/**` – Proxies to the Order service
- `GET /openapi/public.yaml` – Public OpenAPI spec (served by public listener)
- `GET /openapi/private.yaml` – Private OpenAPI spec (served by private listener)

Internal-only (private listener)
- `GET /internal/v1/status` – Build/runtime/config status JSON
- `POST /internal/v1/echo` – Diagnostic echo of headers/body
- `GET /metrics` – Minimal Prometheus-style metrics
- `GET /debug/pprof/*` – Go pprof endpoints (index, heap, goroutine, etc.)
- `GET /debug/vars` – Go expvar JSON

How order proxying works:
- Public path starts with `/api/v1`.
- Before proxying, the gateway strips that prefix.
- Example: `GET /api/v1/orders/123` -> upstream request becomes `GET /orders/123` to the Order service.

## Middleware (Request Flow)
1) Recovery – catches panics and returns a clean JSON 500.
2) Request ID – ensures every request has `X-Request-Id` (added if missing) and echoes it back.
3) Logging – logs method, path, status, duration, and remote address.
4) Route security (only for proxied routes):
   - Rate limiting (token bucket, per client IP) if enabled.
   - JWT Auth (HS256) if enabled.

## Configuration (Environment Variables)
- `ORDER_SERVICE_URL` – Upstream base URL for the Order service.
  - Defaults: local `http://localhost:8081`, Kubernetes `http://order-service.stashfi.svc.cluster.local:8080`.
- `API_STRIP_PREFIX` – Public prefix to remove before proxying (default: `/api/v1`).
- `REQUEST_TIMEOUT_MS` – Per‑request timeout (default: `5000`).
- `AUTH_DISABLE` – Set `true` to disable auth (recommended locally until JWT issuer is ready).
- `JWT_HS256_SECRET` – Required when auth is enabled; HS256 shared secret.
- `RATE_LIMIT_ENABLED` – Enable per‑IP rate limiting (`false` by default).
- `RATE_LIMIT_RPS` – Allowed requests per second per client (default: `10`).
- `RATE_LIMIT_BURST` – Burst capacity per client (default: `20`).
- Logging defaults adapt to environment:
  - `LOG_LEVEL` (`DEBUG|INFO|WARN|ERROR`)
  - `LOG_FORMAT` (`json|text|pretty`)
  - `ENV|GO_ENV|ENVIRONMENT|APP_ENV`

OpenAPI & Spectral
- Public spec file: `specs/public-api.yaml`
- Private spec file: `specs/private-api.yaml`
- Full gateway spec (includes health/ready): `specs/api-gateway.yaml`
- Spectral rules live in `.spectral.yaml` (we require `operationId` and success responses).
- Lint examples:
  - `npx @stoplight/spectral-cli lint specs/public-api.yaml`
  - `docker run --rm -v "$PWD":/work -w /work stoplight/spectral:latest lint specs/public-api.yaml`

Private Listener
- The gateway now runs two listeners by default:
  - Public: `PORT` (default `8080`)
  - Private: `PRIVATE_PORT` (default `8081`)
- In Kubernetes, a second `Service` (`api-gateway-private`) exposes only the private port as ClusterIP.

## Local Development
From repo root:
```bash
mise install  # toolchain
go test ./services/api-gateway/...  # quick check from root

cd services/api-gateway
LOG_LEVEL=DEBUG LOG_FORMAT=pretty go run .
```

You can stub an order service locally on `:8081` that handles `/orders` paths, or point `ORDER_SERVICE_URL` to any HTTP server for testing.

## Deployment
- Kubernetes manifests:
  - `infra/k8s/api-gateway-deployment.yaml`
  - `infra/k8s/api-gateway-service.yaml`
  - `infra/k8s/api-gateway-private-service.yaml`
  - `infra/k8s/public-api-docs-deployment.yaml` and `infra/k8s/public-api-docs-service.yaml`
- Kong routes all `/api/v1` traffic to the API Gateway (DB‑less config in `infra/helm/kong`).
  - Kong also routes `/docs` to the Scalar docs service (`public-api-docs`).

Note: In Kubernetes, the default `ORDER_SERVICE_URL` points to the cluster‑DNS name `order-service.stashfi.svc.cluster.local:8080`. You can override this per‑environment if needed.

## Security
- Auth (optional): JWT HS256. Enable by setting `AUTH_DISABLE=false` and providing `JWT_HS256_SECRET`.
  - Future: Move to RS256/JWKS and centralized issuer.
- Rate limiting (optional): Per client IP token bucket.
- Request ID propagation: `X-Request-Id` forwarded to upstream.

## Observability
- Structured logs via `slog`.
- Standard proxy headers: `X-Forwarded-*` and `Via: stashfi-gateway`.
- Future work: Add Prometheus metrics (`/metrics`) and OpenTelemetry tracing.

## Testing
- Unit tests live in `services/api-gateway/*.go`.
- Proxy logic uses a mock transport in tests (no network bind).
```bash
cd services/api-gateway
go test ./...
```

## What’s Missing (Planned)
- Full order service implementation behind the proxy.
- Metrics and traces.
- Per‑service retry/backoff and circuit breaker.
- Centralized auth (RS256/JWKS) and fine‑grained authorization.

## Where to Look in the Code
- Entry / server: `services/api-gateway/main.go`
- Config: `services/api-gateway/config.go`
- Middleware: `services/api-gateway/middleware.go`
- Reverse proxy: `services/api-gateway/proxy.go`
- Rate limiting: `services/api-gateway/ratelimit.go`
- Tests: `services/api-gateway/*_test.go`
