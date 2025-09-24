# Infrastructure Directory Guide

## First Steps
- Ensure tooling is installed: `mise install`
- For local development, use the kind quickstart below: `scripts/kind-up.sh --build-image --install-kong`
- For manual Helm usage, see the Helm section for local/prod profiles.

## Local Cluster (kind) Quickstart
For a local Kubernetes environment closest to production parity, use kind. This repo includes a preconfigured cluster config that maps Kong proxy NodePorts to localhost.

Commands:
```bash
# 1) Ensure tools are installed (installs kind, kubectl, helm, etc.)
mise install

# 2) Create the cluster, load the image, and apply manifests
#    - Add --build-image to build ./services/api-gateway before loading
#    - Add --install-kong to install the Kong Helm chart (uses values.local.yaml)
scripts/kind-up.sh --build-image --install-kong

# Access Kong (when installed)
open http://localhost:32080
```

Configuration:
```
infra/kind/kind-stashfi.yaml               # kind cluster config
infra/helm/kong/values.yaml                # base chart values (shared defaults)
infra/helm/kong/values.local.yaml          # LOCAL dev overrides (NodePorts, admin HTTP)
infra/helm/kong/values.prod.yaml           # PROD overrides (LB/ClusterIP, admin disabled)
```
The kind config maps Kong NodePorts 32080/32443 to localhost for easy testing.

Profiles:
- Local dev: `-f infra/helm/kong/values.local.yaml`
- Production: `-f infra/helm/kong/values.prod.yaml`

## Directory Layout
```
infra/
├── containers/
│   └── ci-toolbox/        # Docker image used for local or self-hosted CI runs
├── helm/
│   └── kong/              # Kong Gateway Helm chart configuration
└── k8s/                   # Raw Kubernetes manifests for the API Gateway service
```

## Containers (`infra/containers`)
### `ci-toolbox/`
- **Dockerfile** – builds a tooling image on top of `ubuntu:24.04` with Go 1.25.1, Node 24.7.0, Python 3.12, Helm 3.18.6, kubectl 1.34.1, Trivy 0.66.0, Syft 1.32.0, Grype 0.99.1, golangci-lint 2.4.0, Gitleaks 8.28.0, gosec 2.22.8, Semgrep 1.86.0, and other CLIs required by the workflows.
- **Dockerfile.simple** – lightweight variant for fast local testing; installs only the basics (curl, git, Go 1.25.1, Node 24.7.0, Python 3.12, kubectl, Helm). Use it when you need faster builds and can live without the full security scanning toolchain.

Build the toolbox image with `mise run docker:ci-toolbox` or by invoking the `ci-toolbox-build.yml` workflow.

## Helm (`infra/helm/kong`)
### Chart Metadata
- `Chart.yaml` defines a local chart named `stashfi-kong` (`version: 0.1.0`) that wraps the upstream `kong` chart `2.51.0` and targets Kong Gateway `3.9.1` (`appVersion`).
- `Chart.lock` pins the dependency to `https://charts.konghq.com` with digest `sha256:2c6d…`.

### `values.yaml` Highlights
- Runs Kong in **DB-less** mode by setting `env.database: "off"`; routing rules are supplied via `dblessConfig.config`.
- Exposes the admin API internally (`admin.type: ClusterIP`, HTTP only) and the proxy via NodePort (`32080` HTTP, `32443` HTTPS) for ease of local access.
- Declares basic resources (`requests: 100m CPU / 128 Mi`, `limits: 500m / 512 Mi`) and enables the status endpoint on port `8100` with Prometheus annotations.
- Configures declarative routes that forward `/health` and `/ready` plus `/api/v1` traffic to the `api-gateway-service` running inside the cluster.

### Common Commands
```bash
# Install dependencies (downloads kong-2.51.0.tgz into charts/)
helm dependency build infra/helm/kong

# Render manifests for inspection (local profile)
helm template stashfi-kong infra/helm/kong \
  --namespace kong -f infra/helm/kong/values.local.yaml

# Install or upgrade in a cluster
# - Local dev profile
helm upgrade --install stashfi-kong infra/helm/kong \
  --namespace kong --create-namespace \
  -f infra/helm/kong/values.local.yaml

# - Production profile (example)
#   Switch to your cloud context first, then:
helm upgrade --install stashfi-kong infra/helm/kong \
  --namespace kong --create-namespace \
  -f infra/helm/kong/values.prod.yaml
```

## Kubernetes Manifests (`infra/k8s`)
### `api-gateway-deployment.yaml`
- Deploys two replicas of the API Gateway into the `stashfi` namespace.
- Uses image `stashfi/api-gateway:latest` with `PORT`, `PRIVATE_PORT`, `HOST`, and `ENV` environment variables set for the Go servers (public and private listeners).
- Requests `50m` CPU / `64 Mi` memory and caps usage at `100m` / `128 Mi`.
- Defines HTTP liveness (`/health`) and readiness (`/ready`) probes on the named `http` port and enables a pod-level security context (`runAsNonRoot`, UID/GID `1000`).

### `api-gateway-service.yaml`
- ClusterIP service exposing port `8080` and selecting pods labeled `app: api-gateway` within the same namespace.
- Acts as the target for Kong’s upstream routes when using the provided DB-less configuration.

### `api-gateway-private-service.yaml`
- ClusterIP service exposing port `8081` for the private listener (no Kong route by design).
- Use `NetworkPolicy` to restrict which namespaces/workloads can reach this service.

### `public-api-docs-deployment.yaml` and `public-api-docs-service.yaml`
- Deploys a Scalar docs server that serves the public API documentation.
- Kong is configured to route `/docs` to this service.

Use these manifests for quick debugging or as the rendered output checks when adjusting the Helm chart.

## Next Steps
- If you need different ingress behaviour (for example LoadBalancer instead of NodePort), copy `infra/helm/kong/values.yaml` and override the relevant sections with `--values` or `--set`.
- Keep the Docker image tag in the deployment manifest in sync with published versions; `api-gateway-ci.yml` pushes to GHCR on `main`.
- When bumping Kong or Kubernetes versions, update `Chart.yaml`, `Chart.lock`, the Helm validation workflow inputs, and rerun `helm template` to ensure manifests still render correctly.

## Teardown
To stop port-forwards, uninstall Kong/API Gateway, and delete the kind cluster:
```bash
scripts/kind-down.sh                 # default teardown (no Docker cleanup)
scripts/kind-down.sh --remove-images # also remove local images built for this repo
```
Flags:
- `--name NAME`            Cluster name (default: `stashfi`)
- `--keep-cluster`         Do not delete the kind cluster
- `--keep-namespaces`      Do not delete namespaces/resources
- `--remove-images`        Remove local images (e.g., `stashfi/api-gateway:latest`)
- `--prune-docker`         Run `docker image prune -f` after removal
