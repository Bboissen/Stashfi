# API Gateway Service

## First Steps
- Install required tooling: `mise install`
- Run the unit test suite: `go test ./services/api-gateway/...`
- Start the server locally: `go run ./services/api-gateway`
- Build a container image: `docker build -t stashfi/api-gateway:dev ./services/api-gateway`

## Overview
The API Gateway exposes lightweight health, readiness, and status endpoints that can be fronted by Kong or consumed directly for monitoring. It is implemented purely with Go’s standard library and designed to run inside Kubernetes behind the Kong proxy configured in `infra/helm/kong`.

## Local Development
### Prerequisites
- Go 1.25 (the module targets `go 1.25.0`; `mise` installs 1.25.1)
- Docker (for building and running the container)
- Optional: a Kubernetes cluster and Kong if you want to test the full ingress stack

### Commands
```bash
# Install dependencies
mise install

# Run the service
cd services/api-gateway
LOG_LEVEL=DEBUG LOG_FORMAT=pretty go run .

# Run tests
go test ./...
```

### One‑liner: kind + Kong quickstart
This starts a local kind cluster, builds and loads the API gateway image, applies k8s manifests, and installs Kong with DB‑less routing to the gateway and docs. If `infra/helm/kong/values.local.yaml` is not present, the script falls back to the tracked `infra/helm/kong/values.local.yaml.example`.

```bash
# From the repo root
scripts/kind-up.sh --build-image --install-kong

# Then verify via Kong proxy (NodePorts mapped by kind):
curl -s http://localhost:32080/health | jq .
curl -s http://localhost:32080/ready | jq .
curl -s http://localhost:32080/api/v1/status | jq .
# Open API docs UI served via Kong at http://localhost:32080/docs
```

## Configuration
| Variable | Description | Default |
| --- | --- | --- |
| `PORT` | TCP port the HTTP server listens on. | `8080` |
| `HOST` | Interface to bind. | `0.0.0.0` |
| `LOG_LEVEL` | `DEBUG`, `INFO`, `WARN`, or `ERROR`. | `DEBUG` outside production; `INFO` in production. |
| `LOG_FORMAT` | `json`, `text`, or `pretty`. | `pretty` outside production; `json` in production. |
| `ENV` / `GO_ENV` / `ENVIRONMENT` / `APP_ENV` | Environment detection for logging defaults. | `development` |
| `LOG_SOURCE` | Set to `true` to include file:line metadata in logs. | unset |

The binary also supports `--help` and `--version` flags for quick introspection.

## HTTP Endpoints
| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Liveness signal. |
| `GET` | `/ready` | Readiness signal. |
| `GET` | `/api/v1/status` | Service metadata (name, version, status, timestamp). |
| `*` | `/api/v1/orders[/**]` | Proxies to the Order service (path prefix `/api/v1` stripped). |
| `GET` | `/openapi/public.yaml` | Serves the public OpenAPI spec (public listener). |
| `GET` | `/openapi/private.yaml` | Serves the private OpenAPI spec (private listener). |

Private listener endpoints
| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/internal/v1/status` | Build/runtime/config status JSON. |
| `POST` | `/internal/v1/echo` | Diagnostic echo of headers/body. |
| `GET` | `/metrics` | Minimal Prometheus-style metrics. |
| `GET` | `/debug/pprof/*` | Go pprof endpoints. |
| `GET` | `/debug/vars` | Go expvar JSON. |

Responses are JSON encoded and timestamped (Unix seconds).

## Docker Image
The service uses a two-stage build (`services/api-gateway/Dockerfile`):
1. **Builder:** `golang:1.25-alpine3.22` compiles a static binary.
2. **Runtime:** `alpine:3.22` installs `ca-certificates`, creates `appuser` (`uid=1000`), and copies the binary.

Build locally:
```bash
docker build -t stashfi/api-gateway:dev ./services/api-gateway
```
Run the image:
```bash
docker run --rm -p 8080:8080 stashfi/api-gateway:dev
```

## Deployment
- **Kubernetes manifests:** `infra/k8s/api-gateway-deployment.yaml` and `infra/k8s/api-gateway-service.yaml` deploy the service into the `stashfi` namespace.
- **Private Service:** `infra/k8s/api-gateway-private-service.yaml` exposes the private listener (ClusterIP on port 8081) only inside the cluster.
- **Kong integration:** `infra/helm/kong/values.local.yaml` routes `/health`, `/ready`, and `/api/v1` through Kong using the DB-less configuration for local dev. Apply with `helm upgrade --install stashfi-kong infra/helm/kong -n kong -f infra/helm/kong/values.local.yaml`.
 - **Public API Docs (Scalar):** `infra/k8s/public-api-docs-*` deploy a docs UI; Kong routes `/docs` to that service.

## Logging & Safety Nets
- Middleware logs every request with method, path, status, remote address, and duration.
- Panic recovery returns JSON `{ "error": "Internal Server Error" }` with a 500 status, preventing the process from crashing.
- Graceful shutdown waits up to 30 seconds for in-flight requests to finish when SIGINT or SIGTERM is received.

Keep this document in sync when you add new endpoints, environment variables, or dependencies.

## Order Service Routing
- Incoming requests under `/api/v1/orders` are forwarded to the configured `ORDER_SERVICE_URL`.
- The gateway strips the public prefix (default `/api/v1`) before forwarding. Example:
  - Request: `GET /api/v1/orders/123` -> Upstream: `GET /orders/123`.

### Config reference (env)
- `ORDER_SERVICE_URL` (default: `http://localhost:8081` locally; `http://order-service.stashfi.svc.cluster.local:8080` in k8s)
- `API_STRIP_PREFIX` (default: `/api/v1`)
- `REQUEST_TIMEOUT_MS` (default: `5000`)
- `AUTH_DISABLE` (default: `false` in prod, recommend `true` locally until JWT issuer is ready)
- `JWT_HS256_SECRET` (required when auth enabled; HS256)
- `RATE_LIMIT_ENABLED` (default: `false`)
- `RATE_LIMIT_RPS` (default: `10`)
- `RATE_LIMIT_BURST` (default: `20`)

## OpenAPI & Spectral
- Public spec: `specs/public-api.yaml`
- Private spec (placeholder): `specs/private-api.yaml`
- Full gateway spec (includes health/ready): `specs/api-gateway.yaml`
- Lint with Spectral (examples):
  - `npx @stoplight/spectral-cli lint specs/public-api.yaml`
  - `docker run --rm -v "$PWD":/work -w /work stoplight/spectral:latest lint specs/public-api.yaml`

Spec Endpoints
- Public listener: `GET /openapi/public.yaml`
- Private listener: `GET /openapi/private.yaml`
