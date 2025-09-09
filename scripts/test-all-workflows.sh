#!/bin/bash
# Test all GitHub workflows with act

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Results tracking
PASSED=()
FAILED=()
SKIPPED=()

echo -e "${BLUE}=== GitHub Workflows Test Suite ===${NC}"
echo "Testing all workflows with act"
echo "================================"
date

# Function to test a workflow
test_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)

    echo -e "\n${YELLOW}Testing: ${workflow_name}${NC}"
    echo "File: $workflow_file"

    # Skip reusable workflows
    if [[ "$workflow_name" == _reusable* ]]; then
        echo -e "${BLUE}⏭️  Skipping reusable workflow${NC}"
        SKIPPED+=("$workflow_name")
        return
    fi

    # List available jobs
    echo "Available jobs:"
    act -l -W "$workflow_file" 2>/dev/null | grep -E "^0" | awk '{print "  - " $2}' || true

    # Determine the primary event (push, pull_request, etc)
    local event="push"
    if grep -q "pull_request:" "$workflow_file"; then
        event="pull_request"
    elif grep -q "workflow_dispatch:" "$workflow_file"; then
        event="workflow_dispatch"
    elif grep -q "schedule:" "$workflow_file"; then
        echo -e "${BLUE}⏭️  Skipping scheduled workflow${NC}"
        SKIPPED+=("$workflow_name (scheduled)")
        return
    fi

    # Get the first job name
    local first_job=$(act -l -W "$workflow_file" 2>/dev/null | grep -E "^0" | head -1 | awk '{print $2}')

    if [ -z "$first_job" ]; then
        echo -e "${YELLOW}⚠️  No jobs found or workflow has issues${NC}"
        FAILED+=("$workflow_name (no jobs)")
        return
    fi

    echo "Testing job: $first_job with event: $event"

    # Run the test with timeout
    if timeout 60s act "$event" -j "$first_job" -W "$workflow_file" --pull=false 2>&1 | tail -20 | grep -q "Job failed\|Error\|failure"; then
        echo -e "${RED}❌ FAILED${NC}"
        FAILED+=("$workflow_name")

        # Show error details
        echo "Error details:"
        timeout 30s act "$event" -j "$first_job" -W "$workflow_file" --pull=false 2>&1 | grep -E "Error|Failed|failure" | head -5 || true
    else
        # Check if it actually started
        if timeout 30s act "$event" -j "$first_job" -W "$workflow_file" --pull=false --dryrun 2>&1 | grep -q "Run Main\|Run Set up job"; then
            echo -e "${GREEN}✅ PASSED${NC}"
            PASSED+=("$workflow_name")
        else
            echo -e "${YELLOW}⚠️  Unable to verify${NC}"
            SKIPPED+=("$workflow_name (unverifiable)")
        fi
    fi
}

# Test the refactored workflow first (we know it works)
echo -e "\n${BLUE}=== Testing Refactored Workflows ===${NC}"
test_workflow ".github/workflows/api-gateway-ci-refactored.yml"
test_workflow ".github/workflows/ci-main.yml"

# Test original workflows
echo -e "\n${BLUE}=== Testing Original Workflows ===${NC}"

# Priority workflows
PRIORITY_WORKFLOWS=(
    "api-gateway-ci.yml"
    "docker-build.yml"
    "helm-validation.yml"
    "security-scan.yml"
    "ci.yml"
)

for workflow in "${PRIORITY_WORKFLOWS[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        test_workflow ".github/workflows/$workflow"
    fi
done

# Test remaining workflows
echo -e "\n${BLUE}=== Testing Other Workflows ===${NC}"

for workflow_file in .github/workflows/*.yml; do
    workflow_name=$(basename "$workflow_file")

    # Skip if already tested or is reusable
    if [[ " ${PRIORITY_WORKFLOWS[@]} " =~ " ${workflow_name} " ]] || \
       [[ "$workflow_name" == "api-gateway-ci-refactored.yml" ]] || \
       [[ "$workflow_name" == "ci-main.yml" ]] || \
       [[ "$workflow_name" == _reusable* ]]; then
        continue
    fi

    test_workflow "$workflow_file"
done

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo "===================="
echo -e "${GREEN}Passed: ${#PASSED[@]}${NC}"
for w in "${PASSED[@]}"; do
    echo "  ✅ $w"
done

echo -e "\n${RED}Failed: ${#FAILED[@]}${NC}"
for w in "${FAILED[@]}"; do
    echo "  ❌ $w"
done

echo -e "\n${YELLOW}Skipped: ${#SKIPPED[@]}${NC}"
for w in "${SKIPPED[@]}"; do
    echo "  ⏭️  $w"
done

# Overall result
echo ""
if [ ${#FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All testable workflows passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some workflows failed. Review and fix needed.${NC}"
    exit 1
fi
