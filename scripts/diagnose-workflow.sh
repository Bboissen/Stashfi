#!/bin/bash
# Diagnose workflow issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKFLOW="${1:-api-gateway-ci.yml}"

echo -e "${BLUE}=== Workflow Diagnosis Tool ===${NC}"
echo "Workflow: $WORKFLOW"
echo "================================"

# Check if workflow exists
if [ ! -f ".github/workflows/$WORKFLOW" ]; then
    echo -e "${RED}❌ Workflow file not found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}1. Workflow Structure Analysis${NC}"
echo "--------------------------------"

# Check for common issues
echo "Checking for common issues..."

# Check runner specification
echo -n "Runner: "
grep "runs-on:" ".github/workflows/$WORKFLOW" | head -1 | awk '{print $2}'

# Check for actions that need special setup
echo -e "\n${YELLOW}2. External Actions Used${NC}"
echo "------------------------"
grep "uses:" ".github/workflows/$WORKFLOW" | grep -v '#' | awk '{print $2}' | sort -u | while read action; do
    echo "  - $action"
    # Check if action needs Go
    if [[ "$action" == *"setup-go"* ]]; then
        echo -e "    ${YELLOW}⚠️  Needs Go - ensure CI toolbox has Go${NC}"
    fi
    # Check if action needs Node
    if [[ "$action" == *"setup-node"* ]]; then
        echo -e "    ${YELLOW}⚠️  Needs Node - ensure CI toolbox has Node${NC}"
    fi
    # Check if action needs Docker
    if [[ "$action" == *"docker"* ]]; then
        echo -e "    ${YELLOW}⚠️  Needs Docker - may require privileged mode${NC}"
    fi
done

echo -e "\n${YELLOW}3. Jobs and Dependencies${NC}"
echo "------------------------"
act -l -W ".github/workflows/$WORKFLOW" 2>/dev/null | grep -E "^[0-9]" | while read line; do
    stage=$(echo "$line" | awk '{print $1}')
    job=$(echo "$line" | awk '{print $2}')
    echo "  Stage $stage: $job"
done

echo -e "\n${YELLOW}4. Test First Job (Dry Run)${NC}"
echo "---------------------------"
first_job=$(act -l -W ".github/workflows/$WORKFLOW" 2>/dev/null | grep -E "^0" | head -1 | awk '{print $2}')

if [ -n "$first_job" ]; then
    echo "Testing job: $first_job"

    # Dry run to see what would happen
    if timeout 10s act push -j "$first_job" -W ".github/workflows/$WORKFLOW" --dryrun 2>&1 | grep -q "Run Main\|Run Set up job"; then
        echo -e "${GREEN}✓ Job can be started${NC}"
    else
        echo -e "${RED}✗ Job cannot be started${NC}"
        echo "Possible issues:"
        echo "  - Missing required secrets/variables"
        echo "  - Image not available locally"
        echo "  - Syntax errors in workflow"
    fi
else
    echo -e "${RED}No jobs found in workflow${NC}"
fi

echo -e "\n${YELLOW}5. Required Environment${NC}"
echo "-----------------------"
# Check for required secrets
echo "Secrets referenced:"
grep -oE '\$\{\{\s*secrets\.[A-Z_]+\s*\}\}' ".github/workflows/$WORKFLOW" | sed 's/${{//g' | sed 's/}}//g' | sed 's/secrets.//g' | sort -u | while read secret; do
    echo "  - $secret"
done

echo -e "\nVariables referenced:"
grep -oE '\$\{\{\s*vars\.[A-Z_]+\s*\}\}' ".github/workflows/$WORKFLOW" | sed 's/${{//g' | sed 's/}}//g' | sed 's/vars.//g' | sort -u | while read var; do
    echo "  - $var"
done

echo -e "\n${YELLOW}6. Quick Fix Suggestions${NC}"
echo "------------------------"

# Check if it uses setup-go
if grep -q "setup-go" ".github/workflows/$WORKFLOW"; then
    echo "• Uses setup-go action - Consider:"
    echo "  1. Remove setup-go (Go is in CI toolbox)"
    echo "  2. Or add 'continue-on-error: true' to setup-go step"
fi

# Check if it uses setup-node
if grep -q "setup-node" ".github/workflows/$WORKFLOW"; then
    echo "• Uses setup-node action - Consider:"
    echo "  1. Remove setup-node (Node is in CI toolbox)"
    echo "  2. Or add 'continue-on-error: true' to setup-node step"
fi

# Check if it uses docker commands
if grep -q "docker build\|docker push" ".github/workflows/$WORKFLOW"; then
    echo "• Uses Docker commands - Ensure:"
    echo "  1. Docker socket is mounted in act"
    echo "  2. Running with --privileged if needed"
fi

echo -e "\n${GREEN}Diagnosis complete!${NC}"
