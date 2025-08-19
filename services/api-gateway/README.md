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
- `PORT` - Server port (default: 8080)
- `HOST` - Server host (default: 0.0.0.0)
- `ENV` - Environment (development/production)

## API Endpoints

### Health Checks
- `GET /health` - Liveness probe endpoint
- `GET /ready` - Readiness probe endpoint
- `GET /api/v1/status` - Service status information

## Docker Build

```bash
docker build -t stashfi/api-gateway:latest .
```

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

- Runs as non-root user (UID 1000)
- Implements panic recovery middleware
- Graceful shutdown handling
- Proper context cancellation

## Contributing

Please ensure all code follows Go best practices:
- Run `gofmt` before committing
- Add tests for new functionality
- Update this README for significant changes