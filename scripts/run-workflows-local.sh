#!/usr/bin/env bash
set -euo pipefail

# Local runner for GitHub workflows using act
# Usage:
#   scripts/run-workflows-local.sh [--all | --core] [--arch linux/arm64|linux/amd64]
# Defaults to --core and autodetected container arch.

ARCH=""
MODE="core" # core or all

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
RUNNER_IMAGE="catthehacker/ubuntu:act-22.04"
MAP_PLATFORM=("-P" "ubuntu-latest=${RUNNER_IMAGE}" "--container-architecture" "$ARCH")

echo "➡️  Pulling runner image: ${RUNNER_IMAGE} (may take a while)"
docker pull "$RUNNER_IMAGE" >/dev/null

set -x

if [[ "$MODE" == "core" ]]; then
  # Core validation covering the feature work
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/api-gateway-ci.yml -j lint-and-format
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/api-gateway-ci.yml -j test
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/api-gateway-ci.yml -j build

  # Basic CI jobs
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/ci.yml -j api-gateway
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/ci.yml -j docker-build
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/ci.yml -j helm-lint

  # Helm chart validation (lint + template + checks)
  act push "${MAP_PLATFORM[@]}" -W .github/workflows/helm-validation.yml -j lint-and-validate || true
else
  # Run all push-triggered workflows (will be heavy and slow)
  act push "${MAP_PLATFORM[@]}"
fi

set +x
echo "✅ Done. Review logs above for any failures."
