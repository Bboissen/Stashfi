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
- **Kong integration:** `infra/helm/kong/values.yaml` routes `/health`, `/ready`, and `/api/v1` through Kong using the DB-less configuration. Apply with `helm upgrade --install stashfi-kong infra/helm/kong`.

## Logging & Safety Nets
- Middleware logs every request with method, path, status, remote address, and duration.
- Panic recovery returns JSON `{ "error": "Internal Server Error" }` with a 500 status, preventing the process from crashing.
- Graceful shutdown waits up to 30 seconds for in-flight requests to finish when SIGINT or SIGTERM is received.

Keep this document in sync when you add new endpoints, environment variables, or dependencies.
