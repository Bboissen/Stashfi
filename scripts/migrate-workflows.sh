#!/bin/bash
# Script to help migrate existing workflows to use reusable components

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitHub Actions Migration Helper${NC}"
echo "================================"

# Function to analyze a workflow
analyze_workflow() {
    local workflow_file="$1"
    local workflow_name
    workflow_name=$(basename "$workflow_file")

    echo -e "\n${YELLOW}Analyzing: ${workflow_name}${NC}"

    # Check for common patterns
    if grep -q "actions/setup-go" "$workflow_file"; then
        echo "  ✓ Uses Go - can use _reusable-go-test.yml"
    fi

    if grep -q "docker/build-push-action" "$workflow_file"; then
        echo "  ✓ Builds Docker images - can use _reusable-docker-build.yml"
    fi

    if grep -q "azure/setup-helm" "$workflow_file"; then
        echo "  ✓ Uses Helm - can use _reusable-helm-validate.yml"
    fi

    if grep -q "gosec\|semgrep\|codeql\|trivy" "$workflow_file"; then
        echo "  ✓ Security scanning - can use _reusable-security-scan.yml"
    fi

    # Count lines
    local line_count
    line_count=$(wc -l < "$workflow_file")
    echo "  📊 Current size: ${line_count} lines"

    # Estimate reduction
    if [ "$line_count" -gt 100 ]; then
        echo -e "  ${GREEN}💡 Potential reduction: ~80% (to ~$((line_count / 5)) lines)${NC}"
    fi
}

# Function to create a migration template
create_migration_template() {
    local workflow_file="$1"
    local workflow_name
    workflow_name=$(basename "$workflow_file" .yml)
    local output_file=".github/workflows/${workflow_name}-migrated.yml"

    echo -e "\n${YELLOW}Creating migration template for: ${workflow_name}${NC}"

    cat > "$output_file" << 'EOF'
name: WORKFLOW_NAME (Migrated)

on:
  # Copy triggers from original workflow
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

permissions:
  contents: read
  packages: write
  security-events: write

jobs:
  # Example: Go testing
  test:
    name: Test
    uses: ./.github/workflows/_reusable-go-test.yml
    with:
      service_path: ./services/SERVICE_NAME
      go_version: '1.25.1'
      coverage_threshold: 50

  # Example: Security scanning
  security:
    name: Security
    uses: ./.github/workflows/_reusable-security-scan.yml
    with:
      language: go
      scan_path: ./services/SERVICE_NAME

  # Example: Docker build
  docker:
    name: Build
    needs: [test]
    uses: ./.github/workflows/_reusable-docker-build.yml
    with:
      image_name: SERVICE_NAME
      dockerfile_path: ./services/SERVICE_NAME
      push: ${{ github.ref == 'refs/heads/main' }}

  # Example: Helm validation
  helm:
    name: Helm
    uses: ./.github/workflows/_reusable-helm-validate.yml
    with:
      chart_path: ./infra/helm/SERVICE_NAME
EOF

    # Replace placeholders
    sed -i.bak "s/WORKFLOW_NAME/${workflow_name}/g" "$output_file"
    sed -i.bak "s/SERVICE_NAME/${workflow_name}/g" "$output_file"
    rm "${output_file}.bak"

    echo -e "${GREEN}  ✓ Created template: ${output_file}${NC}"
}

# Main execution
echo -e "\n${GREEN}Step 1: Analyzing existing workflows${NC}"
echo "-------------------------------------"

for workflow in .github/workflows/*.yml; do
    # Skip reusable workflows and already migrated ones
    if [[ "$workflow" == *"_reusable"* ]] || [[ "$workflow" == *"-migrated"* ]] || [[ "$workflow" == *"-refactored"* ]]; then
        continue
    fi

    analyze_workflow "$workflow"
done

echo -e "\n${GREEN}Step 2: Workflows to migrate${NC}"
echo "----------------------------"

# List workflows that need migration
workflows_to_migrate=()
for workflow in .github/workflows/*.yml; do
    if [[ "$workflow" != *"_reusable"* ]] && [[ "$workflow" != *"-migrated"* ]] && [[ "$workflow" != *"-refactored"* ]]; then
        workflows_to_migrate+=("$workflow")
        echo "  - $(basename "$workflow")"
    fi
done

# Ask if user wants to create templates
echo -e "\n${YELLOW}Do you want to create migration templates? (y/n)${NC}"
read -r response

if [[ "$response" == "y" ]]; then
    echo -e "\n${GREEN}Step 3: Creating migration templates${NC}"
    echo "------------------------------------"

    for workflow in "${workflows_to_migrate[@]}"; do
        create_migration_template "$workflow"
    done

    echo -e "\n${GREEN}✅ Migration templates created!${NC}"
    echo "Next steps:"
    echo "1. Review and customize the generated templates"
    echo "2. Test locally with: act push -W .github/workflows/WORKFLOW-migrated.yml"
    echo "3. Replace original workflows after testing"
fi

echo -e "\n${GREEN}Migration Checklist:${NC}"
echo "-------------------"
echo "[ ] Build and push CI toolbox image to GHCR"
echo "[ ] Update branch protection rules to use new workflow names"
echo "[ ] Test each migrated workflow with act"
echo "[ ] Archive old workflows to .github/workflows/archived/"
echo "[ ] Update documentation"
echo "[ ] Team training on new patterns"

echo -e "\n${GREEN}Done!${NC}"
