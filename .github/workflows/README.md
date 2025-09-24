# GitHub Actions Workflows

## First Steps
- Clone and enter the repo, then install the pinned tool versions: `git clone https://github.com/Stashfi/Stashfi.git && cd Stashfi && mise install`
- Run the API Gateway unit tests: `go test ./services/api-gateway/...`
- Build the gateway image: `docker build -t stashfi/api-gateway:dev ./services/api-gateway`

Those commands mirror the critical paths exercised by the CI pipelines below.

## Available Workflows

### API Gateway CI (`api-gateway-ci.yml`)
- Triggers on pushes to `main`, feature branches (`feat/**`, `fix/**`), and pull requests that touch the gateway or shared workflow files.
- Invokes `_reusable-go-test.yml` (Go 1.25.1 with race detector, gofmt check, coverage ≥ 50 %) and `_reusable-security-scan.yml`.
- Builds the container image with `_reusable-docker-build.yml` and pushes to GHCR when the ref is `main`.

### API Integration Tests (`api-integration-test.yml`)
- Spins up Postgres and installs Kong Gateway 3.11 on the runner.
- Builds and launches the Go API Gateway, configures Kong routes, and verifies `/health` and `/ready` directly and via Kong.
- Lints `specs/api-gateway.yaml` with Spectral, runs k6 load tests, and executes Go integration tests (`-tags=integration`).

### CI Toolbox Build (`ci-toolbox-build.yml`)
- Builds the toolbox image from `infra/containers/ci-toolbox/Dockerfile` for `linux/amd64` and `linux/arm64` using Buildx.
- Optionally pushes tags (`latest`, `24.04`, per-commit SHA) to `ghcr.io` when running on `main` or when `workflow_dispatch` specifies `push=true`.

### Helm Chart Validation (`helm-validation.yml`)
- Uses `_reusable-helm-validate.yml` to lint the Kong chart with Helm `3.18.6`, kubeconform (Kubernetes `1.31.3` schemas), and Pluto.
- Rebuilds chart dependencies, inspects `values.yaml` with `yq`, and renders a dry-run manifest to highlight missing limits or security context entries.

### Security & Compliance (`security-compliance.yml`)
- Generates an SPDX SBOM with Syft, scans it with Grype, and uploads Trivy filesystem and container SARIF reports.
- Checks Go dependencies with Nancy and `govulncheck`, audits licenses with `go-licenses`, and performs full-history secret detection through the Gitleaks action.

## Reusable Workflows

| File | Purpose |
| --- | --- |
| `_reusable-go-test.yml` | Standard Go lint/test job with caching, gofmt enforcement, race tests, and configurable coverage gate. |
| `_reusable-docker-build.yml` | Buildx-driven Docker build with optional multi-arch push and Trivy image scanning. |
| `_reusable-helm-validate.yml` | Helm render + kubeconform + Pluto validation for a supplied chart path. |
| `_reusable-security-scan.yml` | Filesystem security scans (Gitleaks, Gosec, Semgrep, Trivy) with SARIF upload helpers. |

## Secrets
- All workflows rely on the default `GITHUB_TOKEN`; no additional repository secrets are required to run them as configured.
- Provide extra credentials only when extending workflows (for example Docker Hub credentials for publishing outside GHCR).

## Debugging Tips
- Review the **Actions** tab logs; each job logs tool versions up front for reproducibility.
- Re-run jobs with `workflow_dispatch` if you need to reproduce a failure after updating variables or secrets.
- Use [`act`](https://github.com/nektos/act) locally for quick iteration: `act -W .github/workflows/api-gateway-ci.yml pull_request`.
