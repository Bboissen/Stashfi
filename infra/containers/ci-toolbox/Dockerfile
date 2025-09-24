# syntax=docker/dockerfile:1.7
# CI toolbox image for running GitHub Actions locally via act
# Base: Ubuntu 24.04 (noble)
FROM ubuntu:24.04

# Ensure bash is used with pipefail for RUN steps using pipes
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Versions (keep in sync with mise.toml and .github/VERSIONS.md)
ENV NODE_VERSION=24.7.0
ENV GO_VERSION=1.25.1
ENV PNPM_VERSION=9.9.0

# Core packages
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git git-lfs \
    jq \
    unzip zip \
    build-essential \
    python3 python3-pip python3-venv \
    openssh-client \
    gnupg \
    lsb-release \
    software-properties-common \
    bc \
 && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (not the daemon, since we'll use host's Docker)
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js (exact version) from official binaries
# Use architecture detection to pick the right tarball
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) nodearch=x64 ;; \
    arm64) nodearch=arm64 ;; \
    armhf) nodearch=armv7l ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${nodearch}.tar.xz"; \
  mkdir -p /usr/local/lib/nodejs; \
  tar -xJf "node-v${NODE_VERSION}-linux-${nodearch}.tar.xz" -C /usr/local/lib/nodejs; \
  ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${nodearch}/bin/node /usr/local/bin/node; \
  ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${nodearch}/bin/npm /usr/local/bin/npm; \
  ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${nodearch}/bin/npx /usr/local/bin/npx; \
  ln -s /usr/local/lib/nodejs/node-v${NODE_VERSION}-linux-${nodearch}/bin/corepack /usr/local/bin/corepack; \
  rm -f "node-v${NODE_VERSION}-linux-${nodearch}.tar.xz"; \
  node --version | grep -q "v${NODE_VERSION}"

# Enable Corepack for pnpm
RUN corepack enable && \
    corepack prepare pnpm@${PNPM_VERSION} --activate

# Install Go (exact version) from official binaries
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) goarch=amd64 ;; \
    arm64) goarch=arm64 ;; \
    armhf) goarch=armv7l ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${goarch}.tar.gz" | tar -C /usr/local -xz; \
  ln -s /usr/local/go/bin/go /usr/local/bin/go; \
  ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt; \
  go version | grep -q "go${GO_VERSION}"

# Install additional CLI tools and dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    make \
    gcc \
    libc6-dev \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Install yq (YAML processor)
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  YQ_VERSION="4.47.1"; \
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${arch}" -o /usr/local/bin/yq; \
  chmod +x /usr/local/bin/yq

# Install Helm (matches mise.toml version)
ENV HELM_VERSION=3.18.6
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) helmarch=amd64 ;; \
    arm64) helmarch=arm64 ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${helmarch}.tar.gz" | tar -xz -C /tmp; \
  mv /tmp/linux-${helmarch}/helm /usr/local/bin/helm; \
  rm -rf /tmp/linux-${helmarch}; \
  helm version

# Install kubectl (matches mise.toml version)
ENV KUBECTL_VERSION=1.34.1
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" -o /usr/local/bin/kubectl; \
  chmod +x /usr/local/bin/kubectl; \
  kubectl version --client

# Install kubeconform for Kubernetes manifest validation
ENV KUBECONFORM_VERSION=0.7.0
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) kubeconformarch="amd64" ;; \
    arm64) kubeconformarch="arm64" ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${kubeconformarch}.tar.gz" | tar -xz -C /tmp kubeconform; \
  mv /tmp/kubeconform /usr/local/bin/kubeconform; \
  chmod +x /usr/local/bin/kubeconform; \
  kubeconform -v

# Install pluto for deprecated Kubernetes API detection
ENV PLUTO_VERSION=5.22.5
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) plutoarch="amd64" ;; \
    arm64) plutoarch="arm64" ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/FairwindsOps/pluto/releases/download/v${PLUTO_VERSION}/pluto_${PLUTO_VERSION}_linux_${plutoarch}.tar.gz" | tar -xz -C /tmp pluto; \
  mv /tmp/pluto /usr/local/bin/pluto; \
  chmod +x /usr/local/bin/pluto; \
  pluto version

# Install cosign for container signing
ENV COSIGN_VERSION=2.5.3
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  curl -fsSL "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${arch}" -o /usr/local/bin/cosign; \
  chmod +x /usr/local/bin/cosign; \
  cosign version

# Install trivy for vulnerability scanning
ENV TRIVY_VERSION=0.66.0
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) trivyarch="64bit" ;; \
    arm64) trivyarch="ARM64" ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${trivyarch}.tar.gz" | tar -xz -C /tmp trivy; \
  mv /tmp/trivy /usr/local/bin/trivy; \
  trivy version

# Install golangci-lint (build from source to work with Go 1.25.1)
ENV GOLANGCI_LINT_VERSION=2.4.0
RUN go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v${GOLANGCI_LINT_VERSION} && \
    mv /root/go/bin/golangci-lint /usr/local/bin/

# Install gitleaks for secret scanning
ENV GITLEAKS_VERSION=8.28.0
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) gitleaksarch="x64" ;; \
    arm64) gitleaksarch="arm64" ;; \
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${gitleaksarch}.tar.gz" | tar -xz -C /tmp gitleaks; \
  mv /tmp/gitleaks /usr/local/bin/gitleaks; \
  chmod +x /usr/local/bin/gitleaks

# Install gosec for Go security scanning
RUN go install github.com/securego/gosec/v2/cmd/gosec@v2.22.8 && \
    mv /root/go/bin/gosec /usr/local/bin/

# Install pipx via apt and Semgrep for security analysis (latest version)
ENV PATH="/root/.local/bin:${PATH}"
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    --mount=type=cache,target=/root/.cache/pip \
    apt-get update && apt-get install -y --no-install-recommends pipx && \
    rm -rf /var/lib/apt/lists/* && \
    pipx install "semgrep==1.86.0" && \
    pipx ensurepath && \
    ln -s /root/.local/bin/semgrep /usr/local/bin/semgrep

# Helpful defaults for act
ENV DOCKER_HOST=unix:///var/run/docker.sock

# Suppress Node.js deprecation warnings that come from GitHub Actions
ENV NODE_NO_WARNINGS=1

# Set up GitHub Actions runner environment
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ENV RUNNER_TEMP=/tmp
RUN mkdir -p /opt/hostedtoolcache

# Create a non-root user (optional; most act images run as root)
# RUN useradd -m -s /bin/bash runner && \
#     usermod -aG docker runner
# USER runner

# Show versions to aid debugging
RUN set -eux; \
  printf "Node:\t%s\n" "$(node -v)"; \
  printf "npm:\t%s\n" "$(npm -v)"; \
  printf "pnpm:\t%s\n" "$(pnpm -v)"; \
  printf "Go:\t%s\n" "$(go version)"; \
  printf "Docker:\t%s\n" "$(docker --version || true)"; \
  printf "Buildx:\t%s\n" "$(docker buildx version || true)"; \
  printf "Python:\t%s\n" "$(python3 --version)"; \
  printf "Git:\t%s\n" "$(git --version)"; \
  printf "jq:\t%s\n" "$(jq --version)"

# The container expects the host Docker socket to be mounted by act:
#   --container-options "--privileged -v /var/run/docker.sock:/var/run/docker.sock"
# CI utility image: disable container healthchecks explicitly
HEALTHCHECK NONE
