#!/usr/bin/env bash
set -euo pipefail

# Lightweight workflow validation script
# Can be used in pre-commit hooks or run manually

WORKFLOWS_DIR=".github/workflows"
ERRORS=0

echo "🔍 Validating GitHub Actions workflows..."

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo "❌ Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
fi

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    if command -v yq &> /dev/null; then
        if ! yq eval '.' "$file" > /dev/null 2>&1; then
            echo "❌ Invalid YAML syntax in: $file"
            return 1
        fi
    elif command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "❌ Invalid YAML syntax in: $file"
            return 1
        fi
    else
        # Basic syntax check with grep
        if ! grep -q "^name:" "$file"; then
            echo "⚠️  Missing 'name' field in: $file"
            return 1
        fi
    fi
    return 0
}

# Function to check for common issues
check_common_issues() {
    local file=$1
    local filename
    filename=$(basename "$file")

    local default_registry="ghcr.io/${GITHUB_REPOSITORY_OWNER:-bboissen}/ci-toolbox"

    # Check for CI toolbox image references
    while IFS= read -r registry_match; do
        if [[ "$registry_match" != "$default_registry"* ]]; then
            echo "⚠️  $filename references CI toolbox image '$registry_match' (expected default: $default_registry)"
        fi
    done < <(grep -oE 'ghcr\.io/[[:alnum:]._-]+/ci-toolbox(:[[:alnum:]._+-]+)?' "$file" | sort -u)

    # Check for non-existent service paths
    if grep -q "services/" "$file"; then
        while IFS= read -r service_path; do
            # Extract the path and check if it exists
            path=$(echo "$service_path" | sed 's/.*services/services/' | sed 's/[[:space:]].*//' | tr -d '"')
            if [ ! -d "../../$path" ] && [[ ! "$path" =~ \{\{ ]]; then
                echo "⚠️  $filename references potentially non-existent path: $path"
            fi
        done < <(grep "services/" "$file")
    fi
}

# Validate each workflow file
for workflow in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    [ -e "$workflow" ] || continue

    filename=$(basename "$workflow")

    # Skip backup files
    if [[ "$filename" == *.bak* ]] || [[ "$filename" == *-migrated.yml ]]; then
        continue
    fi

    echo -n "  Checking $filename... "

    if validate_yaml "$workflow"; then
        check_common_issues "$workflow"
        echo "✅"
    else
        ((ERRORS++))
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All workflows validated successfully!"
else
    echo "❌ Found $ERRORS workflow(s) with errors"
    exit 1
fi

# Optional: Run act if available and requested
if [ "${RUN_ACT_TEST:-false}" == "true" ] && command -v act &> /dev/null; then
    echo ""
    echo "🧪 Running local workflow tests with act..."
    echo "  (Set RUN_ACT_TEST=false to skip)"

    # Test specific workflows that are most likely to have issues
    for workflow in api-gateway-ci.yml helm-validation.yml ci-toolbox-build.yml; do
        if [ -f "$WORKFLOWS_DIR/$workflow" ]; then
            echo "  Testing $workflow..."
            if ! act -n -W "$WORKFLOWS_DIR/$workflow" > /dev/null 2>&1; then
                echo "  ⚠️  $workflow may have issues (run 'act -W $WORKFLOWS_DIR/$workflow' for details)"
            fi
        fi
    done
fi
