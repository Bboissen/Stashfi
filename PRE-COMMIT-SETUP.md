# Pre-commit Hooks Setup Guide

This guide explains how to set up and use pre-commit hooks for the Stashfi project. These hooks are configured to match our GitHub Actions CI/CD checks, helping you catch issues before pushing code.

## Quick Start

### Automatic Setup (Recommended)

Run the setup script which will install all tools via mise and configure pre-commit:

```bash
# Run the automated setup
./scripts/setup-pre-commit.sh
```

This script will:
- Install all required tools via mise
- Set up pre-commit hooks
- Create a secrets baseline
- Run a test to verify everything works

### Manual Setup

If you prefer manual setup or need to troubleshoot:

#### 1. Install Tools via mise

All required tools are defined in `mise.toml`. Simply run:

```bash
# Install all tools defined in mise.toml
mise install

# Activate mise environment
eval "$(mise activate bash)"  # or zsh/fish

# Verify tools are installed
mise list
```

#### 2. Install Git Hooks

```bash
# Install pre-commit hooks
pre-commit install --install-hooks

# Install commit-msg hooks for conventional commits
pre-commit install --hook-type commit-msg

# Create detect-secrets baseline
detect-secrets scan --baseline .secrets.baseline

# Verify installation
pre-commit --version
```

## Usage

### Running Hooks Manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run gofmt --all-files
pre-commit run golangci-lint --all-files

# Run on staged files only (default behavior)
pre-commit run

# Skip hooks temporarily (use sparingly!)
git commit --no-verify -m "Emergency fix"
```

### Updating Hooks

```bash
# Update all hooks to latest versions
pre-commit autoupdate

# Clean and reinstall hooks
pre-commit clean
pre-commit install
```

## Hook Categories

### 🔒 Security Checks
- **Gitleaks**: Detects secrets and credentials
- **TruffleHog**: Verified secret scanning
- **detect-secrets**: Python-based secret detection
- **Gosec**: Go security analyzer
- **Semgrep**: Static analysis for security
- **Checkov**: Infrastructure security scanning

### 🚀 Go Checks
- **gofmt**: Go code formatting
- **goimports**: Import statement formatting
- **go vet**: Go code analysis
- **golangci-lint**: Comprehensive Go linting
- **go mod tidy**: Module dependency management
- **govulncheck**: Go vulnerability scanning
- **nancy**: Dependency vulnerability scanning

### ☸️ Kubernetes & Helm
- **helm lint**: Helm chart validation
- **kubectl validate**: K8s manifest validation
- **kubeval**: Kubernetes YAML validation
- **pluto**: Deprecated API detection
- **kong-validate**: Kong configuration validation

### 📝 File & Format Checks
- **YAML/JSON linting**: Syntax and format validation
- **Markdown linting**: Documentation formatting
- **Shell script checks**: shellcheck and shfmt
- **Dockerfile linting**: hadolint

### 📋 General Checks
- **Large file detection**: Prevents large files
- **Merge conflict detection**: Catches merge markers
- **Branch protection**: Prevents direct commits to main
- **Trailing whitespace**: Cleans up whitespace
- **End of file fixer**: Ensures newline at EOF

## Troubleshooting

### Common Issues

1. **Hook fails with "command not found"**
   - Install the required tool (see Required Tools section)
   - Ensure tool is in your PATH

2. **Go-related hooks fail**
   - Make sure you're in the correct directory
   - Run `cd services/api-gateway && go mod download`

3. **Helm hooks fail**
   - Update Helm dependencies: `helm dependency update infra/helm/kong`

4. **Secret detection false positives**
   - Update `.gitleaks.toml` to add exceptions
   - Update `.secrets.baseline` for detect-secrets

### Bypassing Hooks (Emergency Only!)

```bash
# Skip all hooks
SKIP=all git commit -m "Emergency fix"

# Skip specific hooks
SKIP=gofmt,golangci-lint git commit -m "WIP: debugging"

# Force commit without verification
git commit --no-verify -m "Emergency fix"
```

## Secrets Baseline

For `detect-secrets`, create/update the baseline:

```bash
# Create initial baseline
detect-secrets scan --baseline .secrets.baseline

# Update baseline after adding new files
detect-secrets scan --baseline .secrets.baseline --update

# Audit baseline (mark false positives)
detect-secrets audit .secrets.baseline
```

## CI Integration

The same checks run in GitHub Actions. The configuration is designed to:
- Match CI checks locally
- Fail fast on critical issues
- Auto-fix where possible
- Provide clear error messages

## Performance Tips

1. **Use `--files` for partial runs**: When working on specific files
2. **Use `fail_fast: true`** temporarily: To stop on first failure during debugging
3. **Exclude unnecessary paths**: Update `exclude` patterns in `.pre-commit-config.yaml`
4. **Run heavy checks separately**: Some checks like full test suites can be run manually

## Customization

Edit `.pre-commit-config.yaml` to:
- Add/remove hooks
- Adjust hook arguments
- Change file patterns
- Update tool versions

## Best Practices

1. **Don't skip hooks regularly**: They catch real issues
2. **Keep hooks updated**: Run `pre-commit autoupdate` monthly
3. **Fix issues immediately**: Don't accumulate technical debt
4. **Add exceptions carefully**: Update config files for false positives
5. **Run full checks before PR**: `pre-commit run --all-files`

## Getting Help

- Check hook output for specific error messages
- Review `.pre-commit-config.yaml` for hook configuration
- Check individual tool documentation
- Ask team members or create an issue

## Related Files

- `.pre-commit-config.yaml`: Main configuration
- `.gitleaks.toml`: Gitleaks secret detection config
- `.secrets.baseline`: detect-secrets baseline
- `.github/workflows/`: CI/CD configurations to match
