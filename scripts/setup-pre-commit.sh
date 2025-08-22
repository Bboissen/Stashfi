#!/usr/bin/env bash

# Pre-commit setup script for Stashfi project
# This script installs all required tools using mise and sets up pre-commit hooks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "🚀 Setting up pre-commit hooks for Stashfi..."
echo ""

# Check if mise is installed
if ! command -v mise &> /dev/null; then
    print_error "mise is not installed. Please install mise first: https://mise.jdx.dev/getting-started.html"
    exit 1
fi

print_status "mise is installed"

# Install all tools from mise.toml
echo ""
echo "📦 Installing development tools via mise..."
mise install

# Ensure mise environment is activated
eval "$(mise activate bash)"

# Create detect-secrets baseline if it doesn't exist
if [ ! -f .secrets.baseline ]; then
    echo ""
    echo "🔒 Creating detect-secrets baseline..."
    detect-secrets scan --baseline .secrets.baseline || true
    print_status "Created .secrets.baseline"
else
    print_status ".secrets.baseline already exists"
fi

# Install pre-commit hooks
echo ""
echo "🪝 Installing pre-commit hooks..."
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg

print_status "Pre-commit hooks installed"

# Run a test to verify everything works
echo ""
echo "🧪 Testing pre-commit setup..."
if pre-commit run --all-files --show-diff-on-failure --color=always; then
    print_status "All pre-commit checks passed!"
else
    print_warning "Some pre-commit checks failed. This is normal for initial setup."
    print_warning "Review the output above and fix any issues before committing."
fi

echo ""
echo "✅ Pre-commit setup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Review any failures from the test run above"
echo "  2. Run 'pre-commit run --all-files' to test all hooks"
echo "  3. Commit your changes - hooks will run automatically"
echo ""
echo "💡 Tips:"
echo "  - Run 'mise list' to see all installed tools"
echo "  - Run 'pre-commit autoupdate' to update hook versions"
echo "  - See PRE-COMMIT-SETUP.md for detailed documentation"
