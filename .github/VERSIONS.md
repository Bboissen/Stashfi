# Version Management

This document tracks all versions used across the Stashfi project to ensure consistency and reproducibility.

## Core Languages & Runtimes

| Component | Version | Files |
|-----------|---------|-------|
| Go | 1.25.0 | mise.toml, go.mod, Dockerfile, workflows |
| Node.js | 22.18.0 | mise.toml |
| Python | 3.12 | mise.toml |
| Alpine Linux | 3.20.3 | Dockerfile |

## Kubernetes & Container Orchestration

| Component | Version | Usage |
|-----------|---------|-------|
| Kubernetes | 1.31.3 | Validation, testing |
| Kong | 3.9.0 | API Gateway |
| Kong Helm Chart | 2.51.0 | Helm deployment |
| Helm | 3.16.3 | Package management |
| Kind | 0.26.0 | Local K8s testing |
| Minikube | 1.35.0 | Local development |

## GitHub Actions

| Action | Version | Purpose |
|--------|---------|---------|
| actions/checkout | v4 | Code checkout |
| actions/setup-go | v5 | Go environment |
| actions/upload-artifact | v4 | Artifact storage |
| actions/download-artifact | v4 | Artifact retrieval |
| actions/cache | v4 | Caching |
| actions/github-script | v7 | GitHub API |
| github/codeql-action | v3 | Security scanning |
| docker/setup-buildx-action | v3 | Docker buildx |
| docker/build-push-action | v6 | Docker build/push |
| docker/login-action | v3 | Registry login |
| docker/setup-qemu-action | v3 | Multi-arch support |
| azure/setup-kubectl | v4 | kubectl CLI |
| azure/setup-helm | v4 | Helm CLI |

## Security & Quality Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Trivy | 0.31.0 | Container scanning |
| Snyk | 0.4.0 | Vulnerability scanning |
| Gitleaks | 8.21.2 | Secret detection |
| TruffleHog | latest | Secret scanning |
| Gosec | 2.21.5 | Go security |
| golangci-lint | 1.61.0 | Go linting |
| Hadolint | 3.1.0 | Dockerfile linting |
| SonarCloud | 3.2.0 | Code quality |
| Cosign | 2.4.1 | Container signing |
| SLSA Verifier | 2.7.0 | Supply chain |

## Development Tools

| Tool | Version | Purpose |
|------|---------|---------|
| yq | 4.44.6 | YAML processing |
| jq | 1.7.1 | JSON processing |
| kubectl | 1.31.3 | K8s CLI |
| kubeval | 0.16.1 | K8s validation |
| kubeconform | 0.7.0 | K8s schema validation |
| OPA | 0.71.0 | Policy engine |
| Polaris | 9.6.0 | K8s best practices |
| Datree | latest | K8s policies |
| Dive | 0.12.0 | Container analysis |
| Container Structure Test | 1.20.0 | Container validation |
| Syft | 1.18.0 | SBOM generation |
| Grype | 0.82.0 | Vulnerability scanning |
| Nancy | 1.0.46 | Go vulnerability check |
| OSV Scanner | 1.9.1 | Vulnerability database |
| Microsoft sbom-tool | 3.0.1 | SBOM generation |

## Docker Base Images

| Image | Version | Usage |
|-------|---------|-------|
| golang | 1.25.0-alpine3.20 | Build stage |
| gcr.io/distroless/static-debian12 | nonroot | Runtime stage (secure) |
| kong | 3.9.0 | API Gateway |
| alpine | 3.20.3 | Build tools only |

## Pre-commit Hooks

| Hook | Version | Purpose |
|------|---------|---------|
| gitleaks | 8.21.2 | Secret detection |
| golangci-lint | 1.61.0 | Go linting |
| hadolint | 2.13.0 | Dockerfile linting |
| pre-commit-hooks | 5.0.0 | Standard hooks |
| commitizen | 3.30.1 | Commit messages |

## Version Update Policy

1. **Security Updates**: Apply immediately for critical vulnerabilities
2. **Minor Updates**: Review and apply monthly
3. **Major Updates**: Evaluate quarterly with testing
4. **Go Version**: Follow stable releases, test thoroughly before updating
5. **Kubernetes**: Stay within 2 minor versions of latest
6. **Actions**: Update to latest major version quarterly

## Version Verification Commands

```bash
# Check Go version
go version

# Check Node version
node --version

# Check Python version
python --version

# Check Kubernetes version
kubectl version --client

# Check Helm version
helm version

# Check Docker version
docker --version

# Check Kong version
docker run --rm kong:3.9.0 kong version
```

## Automated Version Checking

The `dependency-update.yml` workflow runs weekly to:
- Check for Go module updates
- Check for Docker base image updates
- Check for Helm chart updates
- Create PRs for updates

## Version Pinning Guidelines

1. **Always use specific versions** (not `latest`, `main`, or `*`)
2. **Include patch version** (e.g., `1.25.0` not `1.25`)
3. **Document version changes** in commit messages
4. **Test version updates** in feature branches
5. **Update this document** when versions change

## Known Version Constraints

- Go 1.25.0: Minimum version for enhanced ServeMux routing
- Kubernetes 1.31.3: Latest stable with Gateway API support
- Kong 3.9.0: Latest OSS version with declarative config
- Alpine 3.20.3: Latest stable with minimal CVEs
- Distroless: Using static-debian12:nonroot for security

## Workflow Logic Notes

### Release Workflow
- Prerelease detection works for both tag pushes and manual triggers
- Auto-detects prerelease from version tags containing: alpha, beta, rc, pre
- Staging deployment skipped for prereleases
- Boolean inputs properly handled (not compared as strings)

Last Updated: 2024-12-19
