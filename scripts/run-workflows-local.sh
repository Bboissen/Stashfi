#!/usr/bin/env bash
set -uo pipefail

# Local runner for GitHub workflows using act
# Usage:
#   scripts/run-workflows-local.sh [--all | --core | --security] [--arch linux/arm64|linux/amd64]
# Defaults to --core and autodetected container arch.

ARCH=""
MODE="core" # core, security, or all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"; shift ;;
    --core)
      MODE="core"; shift ;;
    --security)
      MODE="security"; shift ;;
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
  echo "  Or follow: https://github.com/nektos/act#installation" >&2
  exit 1
fi

if [[ -z "$ARCH" ]]; then
  # Derive architecture from system
  case "$(uname -m)" in
    arm64|aarch64) ARCH="linux/arm64" ;;
    x86_64|amd64)  ARCH="linux/amd64" ;;
    *) ARCH="linux/amd64" ;;
  esac
fi

# Resolve CI toolbox registry (defaults to repo owner lowercase)
_owner="${GITHUB_REPOSITORY_OWNER:-bboissen}"
_owner_lc="$(printf '%s' "${_owner}" | tr '[:upper:]' '[:lower:]')"
DEFAULT_TOOLBOX_REGISTRY="ghcr.io/${_owner_lc}/ci-toolbox"
CI_TOOLBOX_REGISTRY="${CI_TOOLBOX_REGISTRY:-$DEFAULT_TOOLBOX_REGISTRY}"

# Always use our CI toolbox from GHCR for consistency with GitHub Actions
RUNNER_IMAGE="${CI_TOOLBOX_REGISTRY}:24.04"

# Check if we're logged in to GHCR by trying to pull
echo "📦 Checking CI toolbox availability..."
if docker pull "${RUNNER_IMAGE}" 2>/dev/null; then
  echo "✅ Using CI toolbox: ${RUNNER_IMAGE}"
else
  echo "⚠️  Failed to pull CI toolbox from GHCR"
  echo ""
  echo "Please authenticate with one of these methods:"
  echo "  1. Interactive: docker login ghcr.io -u <username>"
  echo "  2. With token: echo \$GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin"
  echo "  3. With gh CLI: gh auth token | docker login ghcr.io -u <username> --password-stdin"
  echo ""
  echo "To create a GitHub token: https://github.com/settings/tokens"
  echo "Required scope: read:packages"
  echo ""

  # Try to help with gh CLI if available
  if command -v gh >/dev/null 2>&1; then
    echo "🔧 Detected GitHub CLI. Attempting automatic login..."
    if gh auth token | docker login ghcr.io -u "$(gh api user --jq .login)" --password-stdin 2>/dev/null; then
      echo "✅ Logged in via GitHub CLI"
      # Try pulling again
      if docker pull "${RUNNER_IMAGE}" 2>/dev/null; then
        echo "✅ Successfully pulled CI toolbox"
      else
        echo "❌ Still couldn't pull. Check your token permissions."
        exit 1
      fi
    else
      echo "❌ GitHub CLI auth failed. Please login manually."
      exit 1
    fi
  else
    exit 1
  fi
fi

MAP_PLATFORM=(
  "-P" "ubuntu-24.04=${RUNNER_IMAGE}"
  "-P" "ubuntu-latest=${RUNNER_IMAGE}"
  "--container-architecture" "$ARCH"
)

echo "🚀 Running workflows locally with act"
echo "   Mode: ${MODE}"
echo "   Architecture: ${ARCH}"
echo "   Runner image: ${RUNNER_IMAGE}"
echo ""

# Helper to run a workflow/job and capture result
run_job() {
  local wf="$1"
  local job="${2:-}"
  local label="${wf##*/}"
  [[ -n "$job" ]] && label="${label}:${job}"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔧 Running ${label}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Keep it simple - just use the platform mapping and let act handle the rest
  local cmd=(act push "${MAP_PLATFORM[@]}" -W "$wf")
  [[ -n "$job" ]] && cmd+=(-j "$job")

  if "${cmd[@]}"; then
    RESULTS+=("✅ ${label}")
    return 0
  else
    RESULTS+=("❌ ${label}")
    FAILED+=("${label}")
    return 1
  fi
}

RESULTS=()
FAILED=()

case "$MODE" in
  core)
    echo "📦 Running core workflows..."
    # API Gateway CI
    run_job .github/workflows/api-gateway-ci.yml test
    run_job .github/workflows/api-gateway-ci.yml security
    run_job .github/workflows/api-gateway-ci.yml docker

    # Helm validation
    run_job .github/workflows/helm-validation.yml validate-kong
    run_job .github/workflows/helm-validation.yml kong-specific-validation

    # CI Toolbox build (dry-run)
    echo "ℹ️  Skipping CI toolbox build (would push to registry)"
    ;;

  security)
    echo "🔒 Running security workflows..."
    # Security & Compliance
    run_job .github/workflows/security-compliance.yml sbom-scan
    run_job .github/workflows/security-compliance.yml dependency-check
    run_job .github/workflows/security-compliance.yml license-check
    run_job .github/workflows/security-compliance.yml secret-scan

    # API Gateway security
    run_job .github/workflows/api-gateway-ci.yml security
    ;;

  all)
    echo "🌍 Running all workflows..."
    # Core workflows
    run_job .github/workflows/api-gateway-ci.yml test
    run_job .github/workflows/api-gateway-ci.yml security
    run_job .github/workflows/api-gateway-ci.yml docker

    # Helm validation
    run_job .github/workflows/helm-validation.yml validate-kong
    run_job .github/workflows/helm-validation.yml kong-specific-validation

    # Security & Compliance
    run_job .github/workflows/security-compliance.yml sbom-scan
    run_job .github/workflows/security-compliance.yml dependency-check
    run_job .github/workflows/security-compliance.yml license-check
    run_job .github/workflows/security-compliance.yml secret-scan

    # Integration tests (requires Kong setup)
    echo "ℹ️  Skipping integration tests (requires full Kong setup)"
    # run_job .github/workflows/api-integration-test.yml integration-test
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for r in "${RESULTS[@]}"; do
  echo "  $r"
done

if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo ""
  echo "🎉 All workflows passed!"
  exit 0
else
  echo ""
  echo "⚠️  Failed workflows:"
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "💡 Tips for debugging:"
  echo "  - Run individual job: act push -W .github/workflows/<workflow>.yml -j <job>"
  echo "  - Verbose mode: add -v flag"
  echo "  - List jobs: act -l"
  echo "  - Check Docker: docker ps -a"
  exit 1
fi
