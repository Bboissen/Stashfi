#!/usr/bin/env bash
set -uo pipefail

# Local runner for GitHub workflows using act
# Usage:
#   scripts/run-workflows-local.sh [--all | --core] [--arch linux/arm64|linux/amd64]
# Defaults to --all and autodetected container arch.

ARCH=""
MODE="all" # core or all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"; shift ;;
    --core)
      MODE="core"; shift ;;
    --arch)
      ARCH="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! command -v docker >/dev/null; then
  echo "❌ Docker is required. Please install Docker Desktop." >&2
  exit 1
fi

if ! command -v act >/dev/null; then
  echo "❌ act is required. Install with:"
  echo "  brew install act # macOS" >&2
  exit 1
fi

if ! command -v helm >/dev/null; then
  echo "⚠️  helm not found. Helm-related jobs may fail."
fi

if [[ -z "$ARCH" ]]; then
  # Derive architecture from system
  case "$(uname -m)" in
    arm64|aarch64) ARCH="linux/arm64" ;;
    x86_64|amd64)  ARCH="linux/amd64" ;;
    *) ARCH="linux/amd64" ;;
  esac
fi

# Use a slimmer runner image to reduce pull size
RUNNER_IMAGE="${ACT_IMAGE:-stashfi/ci-toolbox:24.04}"
MAP_PLATFORM=("-P" "ubuntu-latest=${RUNNER_IMAGE}" "--container-architecture" "$ARCH")

if [[ -n "${GHCR_TOKEN:-}" && -n "${GHCR_USER:-}" ]]; then
  echo "Logging into ghcr.io as ${GHCR_USER} for runner image"
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin || true
fi

echo "➡️  Checking runner image: ${RUNNER_IMAGE}"
if ! docker image inspect "$RUNNER_IMAGE" >/dev/null 2>&1; then
  echo "❌ Runner image not found: $RUNNER_IMAGE. Build it with: scripts/build_ci_toolbox.sh"
  exit 1
fi

set -x

# Helper to run a job and capture result
run_job() {
  local wf="$1"; local job="$2"
  local label="${wf##*/}:${job}"
  echo "\n=== Running ${label} ===\n"
  if act push "${MAP_PLATFORM[@]}" --pull=false -W "$wf" -j "$job"; then
    RESULTS+=("OK ${label}")
  else
    RESULTS+=("FAIL ${label}")
  fi
}

RESULTS=()

if [[ "$MODE" == "core" ]]; then
  # Core validation covering the feature work
  run_job .github/workflows/api-gateway-ci.yml lint-and-format
  run_job .github/workflows/api-gateway-ci.yml test
  run_job .github/workflows/api-gateway-ci.yml build
  run_job .github/workflows/api-gateway-ci.yml vulnerability-scan

  # Basic CI jobs
  run_job .github/workflows/ci.yml api-gateway
  run_job .github/workflows/ci.yml docker-build
  run_job .github/workflows/ci.yml helm-lint

  # Helm chart validation (lint + template + checks)
  run_job .github/workflows/helm-validation.yml lint-and-validate
  run_job .github/workflows/helm-validation.yml test-helm-upgrade
else
  # Run all push-triggered workflows (will be heavy and slow)
  # act does not support running all jobs across all workflows in a single command reliably,
  # so we enumerate key workflows that matter locally.
  run_job .github/workflows/api-gateway-ci.yml lint-and-format
  run_job .github/workflows/api-gateway-ci.yml test
  run_job .github/workflows/api-gateway-ci.yml build
  run_job .github/workflows/api-gateway-ci.yml vulnerability-scan

  run_job .github/workflows/ci.yml api-gateway
  run_job .github/workflows/ci.yml docker-build
  run_job .github/workflows/ci.yml helm-lint

  run_job .github/workflows/helm-validation.yml lint-and-validate
  run_job .github/workflows/helm-validation.yml test-helm-upgrade
fi

set +x

echo "\n==== Summary ===="
FAIL_FOUND=0
for r in "${RESULTS[@]}"; do
  echo "$r"
  [[ "$r" == FAIL* ]] && FAIL_FOUND=1
done

if [[ $FAIL_FOUND -eq 0 ]]; then
  echo "✅ All selected jobs passed"
  exit 0
else
  echo "❌ Some jobs failed (see logs above), but all were executed"
  exit 1
fi
