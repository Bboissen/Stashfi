#!/usr/bin/env bash
set -Eeuo pipefail

# Run GitHub Actions jobs locally (via act), sequentially, stopping on first failure.
# Usage:
#   bash scripts/run_workflows_locally.sh                 # run all
#   bash scripts/run_workflows_locally.sh list            # list jobs
#   bash scripts/run_workflows_locally.sh ci-pre-commit   # run specific job(s)
# Apple Silicon: script defaults to linux/amd64 arch for better parity.

IMAGE=${ACT_IMAGE:-catthehacker/ubuntu:act-latest}
ARCH=${ACT_ARCH:-linux/amd64}

FLAGS=(
  "-P" "ubuntu-latest=${IMAGE}"
  "--container-options" "--privileged"
  "--container-architecture" "${ARCH}"
)

# Optional secrets
[[ -n "${GITHUB_TOKEN:-}" ]] && FLAGS+=("-s" "GITHUB_TOKEN=${GITHUB_TOKEN}")
[[ -n "${NVD_API_KEY:-}" ]] && FLAGS+=("-s" "NVD_API_KEY=${NVD_API_KEY}")
[[ -n "${SNYK_TOKEN:-}" ]] && FLAGS+=("-s" "SNYK_TOKEN=${SNYK_TOKEN}")

LOGDIR=${LOGDIR:-reports/act}
mkdir -p "${LOGDIR}"

run() {
  local name="$1"; shift
  echo "\n=== Running: ${name} ===" | tee -a "${LOGDIR}/summary.txt"
  echo "act $*" > "${LOGDIR}/${name}.cmd"
  if ! act "$@" 2>&1 | tee "${LOGDIR}/${name}.log"; then
    echo "❌ Failed: ${name}" | tee -a "${LOGDIR}/summary.txt"
    exit 1
  fi
  echo "✅ Passed: ${name}" | tee -a "${LOGDIR}/summary.txt"
}

# Registry of jobs: name|event|workflow|jobid
JOBS=(
  "ci-pre-commit|pull_request|.github/workflows/ci.yml|pre-commit"
  "ci-api-gateway|pull_request|.github/workflows/ci.yml|api-gateway"
  "ci-docker-build|pull_request|.github/workflows/ci.yml|docker-build"
  "ci-helm-lint|pull_request|.github/workflows/ci.yml|helm-lint"
  "api-lint-format|pull_request|.github/workflows/api-gateway-ci.yml|lint-and-format"
  "api-test|pull_request|.github/workflows/api-gateway-ci.yml|test"
  "api-build|pull_request|.github/workflows/api-gateway-ci.yml|build"
  "api-vuln-scan|pull_request|.github/workflows/api-gateway-ci.yml|vulnerability-scan"
  "docker-build-scan|pull_request|.github/workflows/docker-build.yml|build-and-scan"
  "helm-lint-validate|pull_request|.github/workflows/helm-validation.yml|lint-and-validate"
  "helm-upgrade-test|pull_request|.github/workflows/helm-validation.yml|test-helm-upgrade"
  "integration-kind|pull_request|.github/workflows/integration-test.yml|integration-test-kind"
  "sec-deps|pull_request|.github/workflows/security-scan.yml|dependency-scanning"
  "sec-secrets|pull_request|.github/workflows/security-scan.yml|secret-scanning"
  "sec-licenses|pull_request|.github/workflows/security-scan.yml|license-compliance"
  "sec-infra|pull_request|.github/workflows/security-scan.yml|infrastructure-scanning"
  "sbom-generate|push|.github/workflows/sbom-management.yml|generate-sboms"
  "sbom-analyze|push|.github/workflows/sbom-management.yml|analyze-dependencies"
)

list_jobs() {
  echo "Available jobs:"
  for j in "${JOBS[@]}"; do
    IFS='|' read -r n e w jb <<<"$j"; printf "- %s (%s %s#%s)\n" "$n" "$e" "$w" "$jb";
  done
}

run_job_by_name() {
  local target="$1"
  for j in "${JOBS[@]}"; do
    IFS='|' read -r n e w jb <<<"$j"
    if [[ "$n" == "$target" ]]; then
      run "$n" "$e" -W "$w" -j "$jb" "${FLAGS[@]}"
      return 0
    fi
  done
  echo "Unknown job: $target" >&2
  return 1
}

if [[ "${1:-}" == "list" ]]; then
  list_jobs
  exit 0
fi

if [[ $# -gt 0 ]]; then
  for name in "$@"; do
    run_job_by_name "$name"
  done
else
  for j in "${JOBS[@]}"; do
    IFS='|' read -r n e w jb <<<"$j"
    run "$n" "$e" -W "$w" -j "$jb" "${FLAGS[@]}"
  done
fi

echo "\nAll selected workflows completed. Logs in ${LOGDIR}" | tee -a "${LOGDIR}/summary.txt"
