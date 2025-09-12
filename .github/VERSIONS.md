# Version Management

This document tracks all versions used across the Stashfi project to ensure consistency and reproducibility.

## Core Languages & Runtimes

| Component    | Version | Files                                    |
| ------------ | ------- | ---------------------------------------- |
| Go           | 1.25.1  | mise.toml, go.mod, Dockerfile, workflows |
| Node.js      | 24.7.0  | CI toolbox Dockerfile                    |
| Python       | 3.12    | mise.toml                                |
| Alpine Linux | 3.22    | Dockerfile                               |

## Kubernetes & Container Orchestration

| Component       | Version | Usage               |
| --------------- | ------- | ------------------- |
| Kubernetes      | 1.31.3  | Validation, testing |
| Kong            | 3.9.1   | API Gateway         |
| Kong Helm Chart | 2.51.0  | Helm deployment     |
| Helm            | 3.18.6  | Package management  |
| Kind            | 0.30.0  | Local K8s testing   |
| Minikube        | 1.36.0  | Local development   |

## GitHub Actions

| Action                     | Version | Purpose            |
| -------------------------- | ------- | ------------------ |
| actions/checkout           | v5.0.0  | Code checkout      |
| actions/setup-go           | v6.0.0  | Go environment     |
| actions/upload-artifact    | v4.6.2  | Artifact storage   |
| actions/download-artifact  | v5.0.0  | Artifact retrieval |
| actions/cache              | v4.2.4  | Caching            |
| actions/github-script      | v8      | GitHub API         |
| github/codeql-action       | v3      | Security scanning  |
| docker/setup-buildx-action | v3.11.1 | Docker buildx      |
| docker/build-push-action   | v6.18.0 | Docker build/push  |
| docker/login-action        | v3.5.0  | Registry login     |
| docker/setup-qemu-action   | v3.6.0  | Multi-arch support |
| moby/buildkit              | v0.24.0 | Build toolkit      |
| azure/setup-kubectl        | v4.0.1  | kubectl CLI        |
| azure/setup-helm           | v4.3.1  | Helm CLI           |

## Security & Quality Tools

| Tool          | Version        | Purpose                |
| ------------- | -------------- | ---------------------- |
| Trivy         | action v0.33.1 | Container scanning     |
| Docker Scout  | action v1      | Container scanning     |
| Dockle        | v0.4.15        | Best-practices linting |
| Snyk          | 0.4.0          | Vulnerability scanning |
| Gitleaks      | 8.28.0         | Secret detection       |
| TruffleHog    | 3.90.6         | Secret scanning        |
| Gosec         | 2.22.8         | Go security            |
| golangci-lint | 2.4.0          | Go linting             |
| Hadolint      | 3.1.0          | Dockerfile linting     |
| SonarCloud    | 5.0.0          | Code quality           |
| Cosign        | 2.5.3          | Container signing      |
| SLSA Verifier | 2.7.1          | Supply chain           |

## Development Tools

| Tool                     | Version | Purpose                |
| ------------------------ | ------- | ---------------------- |
| yq                       | 4.47.1  | YAML processing        |
| jq                       | 1.8.1   | JSON processing        |
| kubectl                  | 1.34.1  | K8s CLI                |
| kubeconform              | 0.7.0   | K8s schema validation  |
| OPA                      | 1.8.0   | Policy engine          |
| Polaris                  | 10.1.1  | K8s best practices     |
| Datree                   | latest  | K8s policies           |
| Dive                     | 0.13.1  | Container analysis     |
| Syft                     | 1.32.0  | SBOM generation        |
| Grype                    | 0.99.1  | Vulnerability scanning |
| Nancy                    | 1.0.51  | Go vulnerability check |
| OSV Scanner              | 2.2.2   | Vulnerability database |
| Microsoft sbom-tool      | 3.0.1   | SBOM generation        |

## Docker Base Images

| Image                             | Version           | Usage                  |
| --------------------------------- | ----------------- | ---------------------- |
| golang                            | 1.25.0-alpine3.22 | Build stage            |
| gcr.io/distroless/static-debian12 | nonroot           | Runtime stage (secure) |
| kong                              | 3.9.1             | API Gateway            |
| alpine                            | 3.22              | Build tools only       |

## Pre-commit Hooks

| Hook             | Version | Purpose            |
| ---------------- | ------- | ------------------ |
| gitleaks         | 8.28.0  | Secret detection   |
| golangci-lint    | 2.4.0   | Go linting         |
| hadolint         | 2.13.0  | Dockerfile linting |
| pre-commit-hooks | 6.0.0   | Standard hooks     |
| commitizen       | 3.30.1  | Commit messages    |

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
docker run --rm kong:3.9.1 kong version
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
- Kong 3.9.1: Latest OSS version with declarative config
- Alpine 3.22: Latest stable with minimal CVEs
- Distroless: Using static-debian12:nonroot for security

## Workflow Logic Notes

### Release Workflow

- Prerelease detection works for both tag pushes and manual triggers
- Auto-detects prerelease from version tags containing: alpha, beta, rc, pre
- Staging deployment skipped for prereleases
- Boolean inputs properly handled (not compared as strings)

Last Updated: 2025-09-12
