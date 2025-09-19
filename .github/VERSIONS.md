# Version Management

## Core Tooling
| Component | Version | Source |
| --- | --- | --- |
| Go toolchain | 1.25.1 | `mise.toml` (`go` tool); Go module target is `go 1.25.0` in `services/api-gateway/go.mod`. |
| Node.js | 24.7.0 | `mise.toml` (used for Spectral CLI). |
| Python | 3.12 (via `uv`) | `mise.toml`. |
| Shell tooling | `shellcheck` 0.11.0, `shfmt` 3.12.0, `yq` 4.47.1, `jq` 1.8.1 | `mise.toml`. |

## Kubernetes & Gateway Stack
| Component | Version | Reference |
| --- | --- | --- |
| Helm | 3.18.6 | `mise.toml`, `_reusable-helm-validate.yml`. |
| Kubernetes schema target | 1.31.3 | `.github/workflows/helm-validation.yml` (kubeconform + Pluto). |
| `kubectl` CLI | 1.34.1 | `mise.toml`. |
| Kong Gateway | 3.9.1 | `infra/helm/kong/Chart.yaml` + `values.yaml`. |
| Kong Helm chart | 2.51.0 | `infra/helm/kong/Chart.lock`. |

## Docker Images
| Image | Tag | Usage |
| --- | --- | --- |
| `golang` | 1.25-alpine3.22 | Builder stage for `services/api-gateway/Dockerfile`. |
| `alpine` | 3.22 | Runtime stage for the API Gateway container. |
| `ubuntu` | 24.04 | Base image for `infra/containers/ci-toolbox/Dockerfile`. |
| `kong` | 3.9.1 | Runtime image pulled by the Helm chart (proxy/admin pods). |

## GitHub Actions (Pinned Versions)
| Action | Version |
| --- | --- |
| `actions/checkout` | v5.0.0 |
| `actions/setup-go` | v6.0.0 |
| `actions/cache` | v4 (various jobs) |
| `actions/setup-node` | v4 |
| `docker/setup-qemu-action` | v3.6.0 |
| `docker/setup-buildx-action` | v3.11.1 |
| `docker/build-push-action` | v6.18.0 |
| `docker/login-action` | v3.5.0 |
| `docker/metadata-action` | v5.6.1 or v5.8.0 (per workflow) |
| `aquasecurity/trivy-action` | 0.33.1 |
| `anchore/sbom-action` | v0.17.2 |
| `anchore/scan-action` | v5.2.0 |
| `gitleaks/gitleaks-action` | v2.3.8 |
| `github/codeql-action/upload-sarif` | v3 |

## Security & QA Tooling
| Tool | Version | Notes |
| --- | --- | --- |
| Trivy CLI | 0.66.0 | Installed in CI toolbox (`infra/containers/ci-toolbox/Dockerfile`). |
| Syft | 1.32.0 | Installed via `mise.toml` and used in `security-compliance.yml`. |
| Grype | 0.99.1 | Installed via `mise.toml`, used in `security-compliance.yml`. |
| Nancy | 1.0.51 | Installed on demand in `security-compliance.yml`. |
| `govulncheck` | 1.1.4 | Installed through `mise.toml` / workflows. |
| Gitleaks CLI | 8.28.0 | Available via `mise.toml`; CI also uses the GitHub action wrapper. |
| golangci-lint | 2.4.0 | Cached in `_reusable-go-test.yml`. |

## Update Guidelines
1. Update `mise.toml`, workflow references, and this document in the same pull request when bumping tool versions.
2. Regenerate the CI toolbox image (`ci-toolbox-build.yml`) after changing base images or CLI versions.
3. For Helm/Kong updates, refresh `Chart.lock`, `values.yaml`, and re-run `helm template` to validate manifests.

_Last reviewed: 2025-09-19_
