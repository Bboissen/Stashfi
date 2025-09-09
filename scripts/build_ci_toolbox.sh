#!/usr/bin/env bash
set -euo pipefail
# Build and optionally push the CI toolbox image, then print the digest if available.
# Usage:
#  scripts/build_ci_toolbox.sh [--push] [--tag <tag>] [--registry ghcr.io/<owner>/ci-toolbox]
# Defaults:
#  tag: 24.04
#  registry: local name 'stashfi/ci-toolbox'

PUSH=false
TAG=24.04
REGISTRY="stashfi/ci-toolbox"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH=true; shift ;;
    --tag) TAG="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac

done

IMAGE="${REGISTRY}:${TAG}"

echo "Building ${IMAGE} ..."
docker build -t "$IMAGE" -f infra/containers/ci-toolbox/Dockerfile .

echo "Built: $IMAGE"

if $PUSH; then
  echo "Pushing ${IMAGE} ..."
  docker push "$IMAGE"
  # Try to show the pushed digest via docker inspect
  if digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null); then
    echo "Pushed digest: ${digest}" | sed 's/^/\n/'
  else
    echo "Pushed, but could not determine digest. Use: docker buildx imagetools inspect ${IMAGE}"
  fi
else
  echo "Not pushing. To push to GHCR, run with --push and set REGISTRY, e.g.:"
  echo "  scripts/build_ci_toolbox.sh --push --registry ghcr.io/<owner>/ci-toolbox"
fi
