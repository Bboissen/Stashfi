# GitHub Secrets Configuration Guide

This document describes all GitHub Secrets required for the Stashfi CI/CD workflows.

## Required vs Optional Secrets

### 🔴 Required Secrets (Workflows will fail without these)
None - all workflows are designed to gracefully handle missing secrets.

### 🟡 Recommended Secrets (Enhanced functionality)
- `DOCKERHUB_USERNAME` - For pushing images to Docker Hub
- `DOCKERHUB_TOKEN` - Docker Hub access token

### 🟢 Optional Secrets (Additional features)
All other secrets are optional and enable additional features when configured.

## Secret Descriptions and Setup

### Container Registry Secrets

#### DOCKERHUB_USERNAME / DOCKERHUB_TOKEN
- **Purpose**: Push images to Docker Hub registry
- **Used in**: `release.yml`
- **Setup**:
  1. Go to https://hub.docker.com/settings/security
  2. Create new access token with `public_repo_write` scope
  3. Add as repository secrets:
     - Name: `DOCKERHUB_USERNAME` - Your Docker Hub username
     - Name: `DOCKERHUB_TOKEN` - The generated access token
- **Impact if missing**: Images only pushed to GitHub Container Registry

### Security Scanning Secrets

#### SNYK_TOKEN
- **Purpose**: Advanced container vulnerability scanning
- **Used in**: `docker-build.yml`
- **Setup**:
  1. Sign up at https://snyk.io
  2. Go to Account Settings > Auth Token
  3. Copy token and add as `SNYK_TOKEN`
- **Impact if missing**: Snyk scanning skipped (Trivy still runs)
- **Free tier**: Yes, 200 tests/month

#### SONAR_TOKEN
- **Purpose**: Code quality and security analysis
- **Used in**: `security-scan.yml`
- **Setup**:
  1. Sign up at https://sonarcloud.io
  2. Go to My Account > Security > Generate Token
  3. Add as `SONAR_TOKEN`
  4. Also set `SONAR_ORGANIZATION` and `SONAR_PROJECT_KEY`
- **Impact if missing**: SonarCloud analysis skipped
- **Free tier**: Yes, for public repos

#### NVD_API_KEY
- **Purpose**: Access NIST National Vulnerability Database
- **Used in**: `security-scan.yml`
- **Setup**:
  1. Request API key at https://nvd.nist.gov/developers/request-an-api-key
  2. Add as `NVD_API_KEY`
- **Impact if missing**: Uses rate-limited anonymous access
- **Free tier**: Yes

#### GITLEAKS_LICENSE
- **Purpose**: Advanced features in Gitleaks secret scanning
- **Used in**: `pr-secret-scan.yml`, `security-scan.yml`
- **Setup**:
  1. Purchase license at https://gitleaks.io/products
  2. Add license key as `GITLEAKS_LICENSE`
- **Impact if missing**: Uses open-source features only
- **Free tier**: No, but OSS version works fine

#### DATREE_TOKEN
- **Purpose**: Kubernetes manifest policy validation
- **Used in**: `k8s-validation.yml`
- **Setup**:
  1. Sign up at https://datree.io
  2. Get token from Settings > Account Token
  3. Add as `DATREE_TOKEN`
- **Impact if missing**: Datree validation skipped
- **Free tier**: Yes, 1000 scans/month

### Monitoring & Reporting Secrets

#### CODECOV_TOKEN
- **Purpose**: Code coverage reporting
- **Used in**: `api-gateway-ci.yml`
- **Setup**:
  1. Sign up at https://codecov.io
  2. Add repository
  3. Copy repository upload token
  4. Add as `CODECOV_TOKEN`
- **Impact if missing**: Coverage upload fails (local reporting still works)
- **Free tier**: Yes, for public repos

#### SLACK_WEBHOOK_URL
- **Purpose**: Send notifications to Slack
- **Used in**: `release.yml`
- **Setup**:
  1. Go to https://api.slack.com/apps
  2. Create new app > Incoming Webhooks
  3. Add webhook URL as `SLACK_WEBHOOK_URL`
- **Impact if missing**: No Slack notifications
- **Free tier**: Yes

#### DEPENDENCY_TRACK_API_KEY
- **Purpose**: SBOM management and vulnerability tracking
- **Used in**: `sbom-management.yml`
- **Setup**:
  1. Deploy Dependency-Track (self-hosted)
  2. Generate API key in admin panel
  3. Add as `DEPENDENCY_TRACK_API_KEY`
  4. Also set `DEPENDENCY_TRACK_URL`
- **Impact if missing**: SBOM not uploaded to Dependency-Track
- **Free tier**: Yes (self-hosted)

## Setting Secrets in GitHub

### Repository Secrets (Recommended)
1. Go to repository Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Enter name and value
4. Click "Add secret"

### Organization Secrets (For multiple repos)
1. Go to organization Settings > Secrets and variables > Actions
2. Click "New organization secret"
3. Enter name and value
4. Select repository access
5. Click "Add secret"

### Environment Secrets (For specific environments)
1. Go to repository Settings > Environments
2. Select or create environment
3. Add environment secrets
4. Configure protection rules if needed

## Security Best Practices

1. **Rotate regularly**: Rotate all tokens every 90 days
2. **Least privilege**: Use minimal required permissions
3. **Audit access**: Review secret usage in workflow logs
4. **Use environments**: Separate secrets by environment
5. **Never commit**: Never commit secrets to repository
6. **Document expiry**: Track token expiration dates

## Validation Script

Run this script to check which secrets are configured:

```bash
#!/bin/bash
# Check which secrets are configured (run in GitHub Actions)

SECRETS=(
  "SNYK_TOKEN"
  "CODECOV_TOKEN"
  "SLACK_WEBHOOK_URL"
  "DOCKERHUB_USERNAME"
  "DOCKERHUB_TOKEN"
  "DEPENDENCY_TRACK_API_KEY"
  "SONAR_TOKEN"
  "NVD_API_KEY"
  "GITLEAKS_LICENSE"
  "DATREE_TOKEN"
)

echo "Checking configured secrets..."
for secret in "${SECRETS[@]}"; do
  if [ -n "${!secret}" ]; then
    echo "✅ $secret is configured"
  else
    echo "❌ $secret is not configured"
  fi
done
```

## Priority Order for Setup

1. **Start with**: No secrets (everything works with graceful degradation)
2. **Then add**: `DOCKERHUB_*` for Docker Hub publishing
3. **Next**: `CODECOV_TOKEN` for coverage reporting
4. **Then**: `SNYK_TOKEN` for enhanced security scanning
5. **Finally**: Other secrets based on your needs

## Workflow Impact Matrix

| Secret | Workflow | Impact if Missing | Alternative |
|--------|----------|-------------------|-------------|
| SNYK_TOKEN | docker-build.yml | Skip Snyk scan | Trivy runs |
| CODECOV_TOKEN | api-gateway-ci.yml | Skip upload | Local report |
| SLACK_WEBHOOK_URL | release.yml | No notifications | Check GitHub |
| DOCKERHUB_* | release.yml | No Docker Hub | GHCR only |
| DEPENDENCY_TRACK_API_KEY | sbom-management.yml | No upload | Local SBOM |
| SONAR_TOKEN | security-scan.yml | Skip SonarCloud | Other scans |
| NVD_API_KEY | security-scan.yml | Rate limited | Still works |
| GITLEAKS_LICENSE | pr-secret-scan.yml | OSS features | Still works |
| DATREE_TOKEN | k8s-validation.yml | Skip Datree | Other validation |

## Testing Secrets

Use the provided validation workflow to test secret configuration:

```yaml
name: Validate Secrets
on:
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Check secrets
        run: |
          .github/scripts/validate-secrets.sh
```

## Support

For issues with specific services:
- Snyk: https://support.snyk.io
- Codecov: https://docs.codecov.io
- SonarCloud: https://docs.sonarcloud.io
- Datree: https://hub.datree.io

Last Updated: 2024-12-19
