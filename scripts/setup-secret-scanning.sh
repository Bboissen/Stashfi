#!/bin/bash
# Setup script for local secret scanning

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Setting up Secret Scanning for Stashfi${NC}"
echo ""

# Check OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${OS_TYPE}"

# Function to install tools
install_tool() {
    local tool=$1
    local install_cmd=$2
    
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool is already installed"
    else
        echo -e "${YELLOW}Installing $tool...${NC}"
        eval "$install_cmd"
        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $tool installed successfully"
        else
            echo -e "${RED}✗${NC} Failed to install $tool"
            return 1
        fi
    fi
}

# Install Gitleaks
echo -e "\n${BLUE}1. Installing Gitleaks...${NC}"
if [ "$OS_TYPE" = "Mac" ]; then
    install_tool "gitleaks" "brew install gitleaks"
elif [ "$OS_TYPE" = "Linux" ]; then
    if ! command -v gitleaks &> /dev/null; then
        echo "Installing Gitleaks from GitHub releases..."
        GITLEAKS_VERSION="8.21.2"
        wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
        tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
        sudo mv gitleaks /usr/local/bin/
        rm "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
        echo -e "${GREEN}✓${NC} Gitleaks installed"
    else
        echo -e "${GREEN}✓${NC} Gitleaks is already installed"
    fi
fi

# Install TruffleHog
echo -e "\n${BLUE}2. Installing TruffleHog...${NC}"
if [ "$OS_TYPE" = "Mac" ]; then
    install_tool "trufflehog" "brew install trufflehog"
elif [ "$OS_TYPE" = "Linux" ]; then
    if ! command -v trufflehog &> /dev/null; then
        echo "Installing TruffleHog..."
        curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
        echo -e "${GREEN}✓${NC} TruffleHog installed"
    else
        echo -e "${GREEN}✓${NC} TruffleHog is already installed"
    fi
fi

# Install pre-commit
echo -e "\n${BLUE}3. Installing pre-commit...${NC}"
if command -v python3 &> /dev/null; then
    if ! command -v pre-commit &> /dev/null; then
        echo "Installing pre-commit via pip..."
        pip3 install --user pre-commit
        echo -e "${GREEN}✓${NC} pre-commit installed"
    else
        echo -e "${GREEN}✓${NC} pre-commit is already installed"
    fi
else
    echo -e "${RED}✗${NC} Python3 is required for pre-commit. Please install Python3 first."
fi

# Setup git hooks
echo -e "\n${BLUE}4. Setting up Git hooks...${NC}"
if command -v pre-commit &> /dev/null; then
    pre-commit install
    pre-commit install --hook-type commit-msg
    echo -e "${GREEN}✓${NC} Git hooks installed"
else
    echo -e "${YELLOW}⚠${NC} pre-commit not found, skipping git hooks setup"
fi

# Create local git-secrets configuration
echo -e "\n${BLUE}5. Configuring git-secrets...${NC}"
if [ "$OS_TYPE" = "Mac" ]; then
    if ! command -v git-secrets &> /dev/null; then
        brew install git-secrets
    fi
elif [ "$OS_TYPE" = "Linux" ]; then
    if ! command -v git-secrets &> /dev/null; then
        git clone https://github.com/awslabs/git-secrets.git /tmp/git-secrets
        cd /tmp/git-secrets && sudo make install
        cd - && rm -rf /tmp/git-secrets
    fi
fi

if command -v git-secrets &> /dev/null; then
    # Install git-secrets hooks
    git secrets --install --force
    
    # Add common patterns
    git secrets --register-aws
    
    # Add custom patterns for Stashfi
    git secrets --add 'KONG_[A-Z_]+\s*=\s*["\x27]?[a-zA-Z0-9_\-]{20,}'
    git secrets --add 'API_KEY\s*=\s*["\x27]?[a-zA-Z0-9_\-]{20,}'
    git secrets --add 'SECRET\s*=\s*["\x27]?[a-zA-Z0-9_\-]{20,}'
    git secrets --add 'TOKEN\s*=\s*["\x27]?[a-zA-Z0-9_\-]{20,}'
    git secrets --add 'postgresql://[^:]+:[^@]+@'
    git secrets --add 'mongodb://[^:]+:[^@]+@'
    
    echo -e "${GREEN}✓${NC} git-secrets configured"
else
    echo -e "${YELLOW}⚠${NC} git-secrets not installed"
fi

# Test the setup
echo -e "\n${BLUE}6. Testing secret detection...${NC}"

# Create a temporary test file
TEST_FILE=$(mktemp)
echo 'API_KEY="sk-1234567890abcdefghijklmnopqrstuvw"' > "$TEST_FILE"

echo "Testing with a fake secret..."
if gitleaks detect --source "$TEST_FILE" --config .gitleaks.toml 2>&1 | grep -q "leaks found"; then
    echo -e "${GREEN}✓${NC} Gitleaks is working correctly"
else
    echo -e "${YELLOW}⚠${NC} Gitleaks test didn't detect the test secret"
fi

rm "$TEST_FILE"

# Final summary
echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Secret Scanning Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "Installed tools:"
command -v gitleaks &> /dev/null && echo "  ✓ Gitleaks"
command -v trufflehog &> /dev/null && echo "  ✓ TruffleHog"
command -v pre-commit &> /dev/null && echo "  ✓ pre-commit"
command -v git-secrets &> /dev/null && echo "  ✓ git-secrets"
echo ""
echo "Next steps:"
echo "  1. Run 'pre-commit run --all-files' to test on existing files"
echo "  2. Scan history: 'gitleaks detect --source . --config .gitleaks.toml'"
echo "  3. The pre-commit hooks will run automatically on commit"
echo ""
echo -e "${YELLOW}⚠️  Remember: Never commit secrets!${NC}"
echo "   Use .env.example for templates"
echo "   Store real secrets in GitHub Secrets or a secret manager"