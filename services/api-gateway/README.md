# API Gateway Service

## Overview
The API Gateway service is the primary entry point for all API requests to the Stashfi platform. It leverages Kong API Gateway for routing, authentication, rate limiting, and request/response transformations.

## Architecture
- **Language**: Go
- **Framework**: Standard Library
- **Gateway**: Integrates with Kong for API management.

## Getting Started

### Prerequisites
- Go (version specified in `go.mod`)
- Docker
- A Kubernetes cluster for deployment (e.g., minikube for local development)

### Local Development
1.  **Install dependencies**:
    ```bash
    go mod download
    ```
2.  **Run the service**:
    ```bash
    go run main.go
    ```
3.  **Run tests**:
    ```bash
    go test ./...
    ```

## Configuration
The service is configured using environment variables.

-   `PORT`: The port on which the server listens. Defaults to `8080`.
-   `HOST`: The host on which the server listens. Defaults to `0.0.0.0`.
-   `LOG_LEVEL`: Logging verbosity (`DEBUG`, `INFO`, `WARN`, `ERROR`). Defaults to `INFO` in production and `DEBUG` in development.
-   `LOG_FORMAT`: Log output format (`json`, `text`). Defaults to `json` in production and `text` in development.
-   `ENV`: Sets the environment (`production`, `development`).

**Example for development:**
```bash
LOG_LEVEL=DEBUG LOG_FORMAT=text go run main.go
```

## API Endpoints

### Health Checks
- `GET /health`: Liveness probe.
- `GET /ready`: Readiness probe.
- `GET /api/v1/status`: Service status information.

## Docker Build
To build the Docker image for the service:
```bash
docker build -t stashfi/api-gateway:latest .
```
The build process uses a multi-stage `Dockerfile` and Google's distroless images for a minimal and secure final image.

## Deployment
This service is designed for Kubernetes. Deployment manifests are located in the `/infra/k8s/` directory.

## Security
- Runs as a non-root user inside a minimal distroless container.
- The container has no shell or package manager, reducing the attack surface.
- The compiled Go binary is statically linked with no external dependencies.
- Implements graceful shutdown and panic recovery.

## Contributing
- Please format your code with `gofmt`.
- Add tests for new features.
- Update documentation when making significant changes.
