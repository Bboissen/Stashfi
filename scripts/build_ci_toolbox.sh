#!/usr/bin/env bash
set -euo pipefail
# Build and optionally push the CI toolbox image with multi-architecture support
# Usage:
#  scripts/build_ci_toolbox.sh [--push] [--tag <tag>] [--registry ghcr.io/<owner>/ci-toolbox] [--platform <platforms>]
# Defaults:
#  tag: 24.04
#  registry: ghcr.io/${GITHUB_REPOSITORY_OWNER:-bboissen}/ci-toolbox (override with CI_TOOLBOX_REGISTRY)
#  platform: linux/amd64,linux/arm64 (multi-arch by default)

PUSH=false
TAG=24.04
DEFAULT_REGISTRY="ghcr.io/${GITHUB_REPOSITORY_OWNER:-bboissen}/ci-toolbox"
REGISTRY="${CI_TOOLBOX_REGISTRY:-$DEFAULT_REGISTRY}"
PLATFORMS="linux/amd64,linux/arm64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH=true; shift ;;
    --tag) TAG="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --platform) PLATFORMS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

IMAGE="${REGISTRY}:${TAG}"

# Ensure buildx is available and set up for multi-arch
if ! docker buildx version >/dev/null 2>&1; then
  echo "❌ Docker buildx is required for multi-arch builds"
  echo "   Please update Docker Desktop or install buildx plugin"
  exit 1
fi

# Create or use multi-arch builder
if ! docker buildx ls | grep -q "multiarch.*running"; then
  echo "🔧 Creating multi-arch builder..."
  docker buildx create --name multiarch --use || docker buildx use multiarch
fi

echo "🏗️  Building ${IMAGE} for platforms: ${PLATFORMS}"
echo "   This may take several minutes..."

BUILD_ARGS=(
  "--platform" "${PLATFORMS}"
  "-t" "${IMAGE}"
  "-t" "${REGISTRY}:latest"
  "-f" "infra/containers/ci-toolbox/Dockerfile"
  "--cache-from" "type=registry,ref=${IMAGE}"
  "--cache-to" "type=inline"
)

if $PUSH; then
  BUILD_ARGS+=("--push")
  echo "   Will push to registry after build"
else
  BUILD_ARGS+=("--load")
  # Note: --load only works for single platform, so skip if multi-platform
  if [[ "${PLATFORMS}" == *","* ]]; then
    echo "⚠️  Multi-platform build without push will not load images locally"
    echo "   Add --push to push to registry, or use single --platform for local load"
    BUILD_ARGS=("${BUILD_ARGS[@]/--load/}")
  fi
fi

# Build the image
if docker buildx build "${BUILD_ARGS[@]}" .; then
  echo "✅ Build successful: $IMAGE"

  if $PUSH; then
    echo "📦 Pushed to registry. To inspect:"
    echo "   docker buildx imagetools inspect ${IMAGE}"
  else
    echo "💡 To push to registry, run with --push"
  fi
else
  echo "❌ Build failed"
  exit 1
fi
