# API Gateway Service

## Overview
The API Gateway service is the entry point for all API requests in the Stashfi platform. It handles routing, authentication, rate limiting, and request/response transformation through Kong API Gateway integration.

## Architecture
- **Language**: Go 1.25
- **HTTP Routing**: Go 1.22+ built-in enhanced ServeMux (stdlib)
- **Logging**: slog for structured logging (stdlib)
- **Dependencies**: Zero external dependencies - pure stdlib
- **Deployment**: Kubernetes with health/readiness probes
- **Gateway**: Integrates with Kong for API management

## Getting Started

### Prerequisites
- Go 1.25 or higher
- Docker for containerization
- Access to Kubernetes cluster (minikube for local development)

### Local Development

1. **Install dependencies**:
```bash
go mod download
```

2. **Run locally**:
```bash
go run main.go
```

3. **Build binary**:
```bash
go build -o api-gateway .
```

4. **Run tests**:
```bash
go test ./...
```

### Environment Variables

#### Server Configuration
- `PORT` - Server port (default: 8080)
- `HOST` - Server host (default: 0.0.0.0)

#### Logging Configuration
The service supports flexible runtime logging configuration:

| Variable | Description | Values | Default |
|----------|-------------|--------|---------|
| `LOG_LEVEL` | Sets the logging verbosity | `DEBUG`, `INFO`, `WARN`, `ERROR` | `INFO` (prod), `DEBUG` (dev) |
| `LOG_FORMAT` | Output format for logs | `json`, `text`, `pretty` | `json` (prod), `pretty` (dev) |
| `LOG_SOURCE` | Include source file/line in logs | `true`, `false` | `false` |
| `ENV` | Primary environment indicator | `production`, `development`, `staging` | `development` |
| `GO_ENV` | Alternative to ENV | `production`, `development`, `staging` | - |
| `ENVIRONMENT` | Alternative to ENV | `production`, `development`, `staging` | - |
| `APP_ENV` | Alternative to ENV | `production`, `development`, `staging` | - |

The service automatically detects production environment when:
- Any environment variable contains "prod" or "production"
- Running in Kubernetes (detected via `KUBERNETES_SERVICE_HOST`)

#### Configuration Examples

**Development with debug logging:**
```bash
LOG_LEVEL=DEBUG LOG_FORMAT=pretty go run main.go
```

**Production with JSON logs:**
```bash
ENV=production LOG_LEVEL=INFO LOG_FORMAT=json ./api-gateway
```

**Kubernetes deployment:**
```yaml
env:
  - name: LOG_LEVEL
    value: "INFO"
  - name: LOG_FORMAT
    value: "json"
  - name: ENV
    value: "production"
```

## API Endpoints

### Health Checks
- `GET /health` - Liveness probe endpoint
- `GET /ready` - Readiness probe endpoint
- `GET /api/v1/status` - Service status information

## Docker Build

```bash
# Basic build
docker build -t stashfi/api-gateway:latest .

# Build with version information
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +%Y%m%d-%H%M%S) \
  --build-arg GIT_COMMIT=$(git rev-parse --short HEAD) \
  -t stashfi/api-gateway:1.0.0 .

# Multi-platform build
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +%Y%m%d-%H%M%S) \
  --build-arg GIT_COMMIT=$(git rev-parse --short HEAD) \
  -t stashfi/api-gateway:1.0.0 \
  --push .
```

## Container Security

The API Gateway uses Google's distroless base image for maximum security:
- **No shell**: Cannot execute shell commands even if compromised
- **No package manager**: Cannot install additional software
- **Minimal surface area**: Only contains the application binary
- **Non-root by default**: Runs as UID 65532

## Deployment

The service is deployed as part of the Stashfi platform using Kubernetes manifests located in `/infra/k8s/`.

### Resource Requirements
- **Requests**: 50m CPU, 64Mi Memory
- **Limits**: 100m CPU, 128Mi Memory

## Development Workflow

1. Make changes to the code
2. Run tests: `go test ./...`
3. Build and test Docker image locally
4. Deploy to minikube for integration testing
5. Submit PR with passing tests

## Monitoring

The service uses Go's standard `slog` package for structured logging:
- **Production**: JSON format for easy parsing by log aggregators
- **Development**: Text format for human readability

All requests are logged with:
- Method, path, status code
- Request duration
- Remote address

## Security

- **Distroless container**: No shell, package managers, or unnecessary binaries
- **Runs as non-root user**: UID 65532 (distroless nonroot)
- **Static binary**: Fully self-contained with no external dependencies
- **Minimal attack surface**: Only the application binary in the container
- **Panic recovery middleware**: Prevents crashes from unhandled errors
- **Graceful shutdown**: Proper cleanup on termination
- **Context cancellation**: Request lifecycle management

## Contributing

Please ensure all code follows Go best practices:
- Run `gofmt` before committing
- Add tests for new functionality
- Update this README for significant changes
- Use `any` instead of `interface{}` (Go 1.18+)
- Prefer standard library over external dependencies