#!/usr/bin/env bash
set -Eeuo pipefail

# Local helper to build and scan the API Gateway image similar to CI.

REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo .)")/api-gateway}"
# Enforce lowercase for Docker/GHCR reference format
IMAGE_NAME="$(echo "${IMAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
CONTEXT="${CONTEXT:-services/api-gateway}"
TAG="${TAG:-scan-local}"
PLATFORM="${PLATFORM:-linux/amd64}"

NO_SBOM=${NO_SBOM:-false}          # set to true to skip sbom/provenance
DEBUG=${DEBUG:-false}

if [[ ${DEBUG} == "true" ]]; then
  export BUILDX_DEBUG=1
  set -x
fi

echo "[i] Using context: ${CONTEXT}"
echo "[i] Target image: ${REGISTRY}/${IMAGE_NAME}:${TAG} (${PLATFORM})"

command -v docker >/dev/null 2>&1 || { echo "[!] docker is required"; exit 1; }
command -v trivy >/dev/null 2>&1 || echo "[i] trivy not found; vulnerability scan will be skipped"
command -v hadolint >/dev/null 2>&1 || echo "[i] hadolint not found; Dockerfile lint will be skipped"

# Ensure a buildx builder exists
if ! docker buildx inspect localbuilder >/dev/null 2>&1; then
  echo "[i] Creating buildx builder 'localbuilder'"
  docker buildx create --name localbuilder --use >/dev/null
fi

BUILDX_ARGS=(
  "--platform" "${PLATFORM}"
  "--tag" "${REGISTRY}/${IMAGE_NAME}:${TAG}"
  "--file" "${CONTEXT}/Dockerfile"
  "--output" "type=docker"
  "--build-arg" "VERSION=$(git rev-parse --short HEAD 2>/dev/null || date +%s)"
  "--build-arg" "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  "--build-arg" "VCS_REF=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
)

if [[ ${NO_SBOM} != "true" ]]; then
  BUILDX_ARGS+=("--provenance=mode=max" "--sbom=true")
fi

echo "[i] Building image with buildx (sbom/provenance: $([[ ${NO_SBOM} == true ]] && echo disabled || echo enabled))"
set +e
docker buildx build "${BUILDX_ARGS[@]}" "${CONTEXT}"
status=$?
set -e

if [[ $status -ne 0 && ${NO_SBOM} != "true" ]]; then
  echo "[!] Build with SBOM/provenance failed; retrying without those features"
  docker buildx build \
    --platform "${PLATFORM}" \
    --tag "${REGISTRY}/${IMAGE_NAME}:${TAG}" \
    --file "${CONTEXT}/Dockerfile" \
    --output type=docker \
    --build-arg "VERSION=$(git rev-parse --short HEAD 2>/dev/null || date +%s)" \
    --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg "VCS_REF=$(git rev-parse HEAD 2>/dev/null || echo unknown)" \
    "${CONTEXT}"
fi

echo "[i] Image built: ${REGISTRY}/${IMAGE_NAME}:${TAG}"

if command -v trivy >/dev/null 2>&1; then
  echo "[i] Running Trivy scan"
  trivy image --severity CRITICAL,HIGH --ignore-unfixed --format table "${REGISTRY}/${IMAGE_NAME}:${TAG}" || true
fi

if command -v hadolint >/dev/null 2>&1; then
  echo "[i] Running Hadolint"
  hadolint "${CONTEXT}/Dockerfile" || true
fi

echo "[✓] Done"
