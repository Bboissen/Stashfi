#!/bin/bash
# Quick fix for workflows to make them testable with act

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Workflow Quick Fix Tool ===${NC}"
echo "This will make workflows testable with act"
echo "========================================="

# Backup directory
BACKUP_DIR=".github/workflows/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "\n${YELLOW}Creating backups in $BACKUP_DIR${NC}"

# Function to fix a workflow
fix_workflow() {
    local workflow="$1"
    local name=$(basename "$workflow")

    # Skip reusable and already migrated workflows
    if [[ "$name" == _reusable* ]] || [[ "$name" == *-refactored.yml ]] || [[ "$name" == *-migrated.yml ]]; then
        echo -e "${BLUE}Skipping $name (already migrated/reusable)${NC}"
        return
    fi

    echo -e "\n${YELLOW}Fixing: $name${NC}"

    # Backup original
    cp "$workflow" "$BACKUP_DIR/$name"

    # Create temporary fixed version
    local temp_file="/tmp/$name.fixed"
    cp "$workflow" "$temp_file"

    # Fix 1: Add continue-on-error to setup actions
    if grep -q "uses:.*setup-go" "$workflow"; then
        echo "  • Adding continue-on-error to setup-go"
        # Use perl for multi-line replacement
        perl -i -pe 's/(uses:\s*actions\/setup-go[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    if grep -q "uses:.*setup-node" "$workflow"; then
        echo "  • Adding continue-on-error to setup-node"
        perl -i -pe 's/(uses:\s*actions\/setup-node[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    if grep -q "uses:.*setup-helm" "$workflow"; then
        echo "  • Adding continue-on-error to azure/setup-helm"
        perl -i -pe 's/(uses:\s*azure\/setup-helm[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    # Fix 2: Add continue-on-error to artifact uploads (fail locally)
    if grep -q "uses:.*upload-artifact" "$workflow"; then
        echo "  • Adding continue-on-error to upload-artifact"
        perl -i -pe 's/(uses:\s*actions\/upload-artifact[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    # Fix 3: Add continue-on-error to codecov
    if grep -q "uses:.*codecov" "$workflow"; then
        echo "  • Adding continue-on-error to codecov"
        perl -i -pe 's/(uses:\s*codecov\/codecov-action[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    # Fix 4: Make external linter actions optional
    if grep -q "uses:.*golangci-lint-action" "$workflow"; then
        echo "  • Adding continue-on-error to golangci-lint-action"
        perl -i -pe 's/(uses:\s*golangci\/golangci-lint-action[^\n]*)\n/$1\n        continue-on-error: true\n/' "$temp_file"
    fi

    # Check if any changes were made
    if diff -q "$workflow" "$temp_file" > /dev/null; then
        echo -e "  ${GREEN}✓ No changes needed${NC}"
    else
        mv "$temp_file" "$workflow"
        echo -e "  ${GREEN}✓ Fixed and saved${NC}"
    fi
}

# Process all workflows
echo -e "\n${BLUE}Processing workflows...${NC}"

for workflow in .github/workflows/*.yml; do
    fix_workflow "$workflow"
done

echo -e "\n${GREEN}=== Quick Fix Complete ===${NC}"
echo "Backups saved in: $BACKUP_DIR"
echo ""
echo "Test with:"
echo "  act push -W .github/workflows/YOUR-WORKFLOW.yml"
echo ""
echo "To restore originals:"
echo "  cp $BACKUP_DIR/*.yml .github/workflows/"
echo ""
echo -e "${YELLOW}Note: This is a temporary fix. Full migration is recommended.${NC}"
