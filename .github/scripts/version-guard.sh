#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "🔎 Running version guard..."

fail=0

check() {
  local desc="$1"; shift
  local pattern="$1"; shift
  local paths=("$@")

  # ripgrep preferred; fallback to grep
  if command -v rg >/dev/null 2>&1; then
    if rg -n --no-heading -e "$pattern" "${paths[@]}"; then
      echo "❌ $desc"
      fail=1
    else
      echo "✅ $desc: none found"
    fi
  else
    if grep -RInE "$pattern" "${paths[@]}"; then
      echo "❌ $desc"
      fail=1
    else
      echo "✅ $desc: none found"
    fi
  fi
}

targets=(".github/workflows" ".github/actions")

# Disallow floating refs in actions
check "Floating action refs (@master/@main/@latest)" \\
      "uses:\\s*[^@\\s]+/[^@\\s]+@(?:master|main|latest)\\b" \\
      "${targets[@]}"

# Disallow major-only action pins (e.g., @v3 or @3)
check "Major-only action pins (use full tag like v3.30.0)" \\
      "uses:\\s*[^@\\s]+/[^@\\s]+@(?:v?\\d+)$" \\
      "${targets[@]}"

# Disallow container :latest usage in docker run or image: fields
check \
  "Docker images using :latest tag (docker run/image:)" \
  "^(?:\\s*docker\\s+run.*|\\s*image:\\s*)[^\n]*:latest\\b" \
  "${targets[@]}"

# Disallow 'downloads/latest' URLs in install scripts
check "Use of downloads/latest URLs (pin exact version)" \\
      "downloads/latest" \\
      "${targets[@]}"

if [[ $fail -ne 0 ]]; then
  echo "\n🚫 Version guard failed. Please pin the versions indicated above."
  exit 1
fi

echo "\n✅ Version guard passed."
exit 0
