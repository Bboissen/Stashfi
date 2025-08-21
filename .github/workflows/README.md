# GitHub Actions Workflows Documentation

## Overview

This repository uses a comprehensive CI/CD pipeline powered by GitHub Actions. Our workflows cover everything from code quality and security to deployment and monitoring.

## Workflow Categories

### 🔧 Core CI/CD Workflows

#### 1. **API Gateway CI** (`api-gateway-ci.yml`)
- **Triggers**: Push to main, PRs
- **Purpose**: Validates Go code quality, runs tests, builds binaries
- **Key Features**:
  - Multi-version Go testing (1.24, 1.25)
  - Race condition detection
  - Coverage reporting with 70% threshold
  - Cross-platform builds (linux/darwin/windows)
  - Vulnerability scanning

#### 2. **Docker Build & Scan** (`docker-build.yml`)
- **Triggers**: Push to main, PRs, tags
- **Purpose**: Build and scan container images
- **Key Features**:
  - Multi-architecture builds (amd64, arm64)
  - Trivy and Snyk vulnerability scanning
  - SBOM generation
  - Image signing with Cosign
  - Hadolint Dockerfile linting

#### 3. **Integration Tests** (`integration-test.yml`)
- **Triggers**: Push to main, PRs, nightly
- **Purpose**: End-to-end testing with real Kubernetes
- **Key Features**:
  - Kind cluster testing
  - Load testing with k6
  - Chaos testing support
  - Smoke tests
  - Minikube alternative tests

### 🔒 Security & Compliance

#### 4. **Security Scanning** (`security-scan.yml`)
- **Triggers**: Push, PRs, weekly schedule
- **Purpose**: Comprehensive security analysis
- **Key Features**:
  - SAST with Gosec, Semgrep, CodeQL
  - Dependency vulnerability scanning
  - Secret detection (Gitleaks, TruffleHog)
  - License compliance checking
  - Infrastructure security (Checkov, Terrascan)

### 📦 Infrastructure Validation

#### 5. **Helm Validation** (`helm-validation.yml`)
- **Triggers**: Changes to Helm charts
- **Purpose**: Validate Helm chart configurations
- **Key Features**:
  - Chart linting and templating
  - Dependency validation
  - Kubernetes API compatibility
  - Upgrade path testing
  - Security policy scanning

#### 6. **Kubernetes Validation** (`k8s-validation.yml`)
- **Triggers**: Changes to K8s manifests
- **Purpose**: Validate Kubernetes configurations
- **Key Features**:
  - Manifest syntax validation
  - API deprecation checks
  - Security policy validation (OPA)
  - Resource specification checks
  - RBAC validation

### 🚀 Release & Deployment

#### 7. **Release Automation** (`release.yml`)
- **Triggers**: Version tags (v*)
- **Purpose**: Automated release process
- **Key Features**:
  - Multi-platform binary builds
  - Container image publishing
  - Helm chart packaging
  - Changelog generation
  - GitHub Release creation
  - Staging deployment

### 📊 Monitoring & Maintenance

#### 8. **Performance Benchmarking** (`benchmark.yml`)
- **Triggers**: Push to main, PRs, weekly
- **Purpose**: Track performance metrics
- **Key Features**:
  - Go benchmarks with regression detection
  - Load testing with k6
  - Memory profiling
  - Historical trend tracking
  - Automatic regression alerts

#### 9. **Dependency Updates** (`dependency-update.yml`)
- **Triggers**: Weekly schedule
- **Purpose**: Keep dependencies current
- **Key Features**:
  - Go module updates
  - Docker base image updates
  - Helm dependency updates
  - Automated PR creation
  - Security audit after updates

#### 10. **PR Automation** (`pr-automation.yml`)
- **Triggers**: PR events
- **Purpose**: Streamline PR workflow
- **Key Features**:
  - Auto-labeling based on files changed
  - PR validation (title, description)
  - Auto-assign reviewers
  - Size complexity warnings
  - Test coverage comments
  - Slash command support

#### 11. **Workflow Dashboard** (`dashboard.yml`)
- **Triggers**: Weekly schedule
- **Purpose**: Workflow metrics and status
- **Key Features**:
  - Success rate tracking
  - Performance metrics
  - Cost analysis
  - Automated reporting

#### 12. **Cost Analysis** (`cost-analysis.yml`)
- **Triggers**: Monthly
- **Purpose**: Track CI/CD costs
- **Key Features**:
  - Usage metrics
  - Cost estimation
  - Optimization recommendations

#### 13. **Cleanup** (`cleanup.yml`)
- **Triggers**: Weekly schedule
- **Purpose**: Repository maintenance
- **Key Features**:
  - Artifact cleanup
  - Workflow run pruning
  - Container image cleanup
  - Cache optimization

## Secrets Required

Configure these secrets in your repository settings:

```yaml
# Required
GITHUB_TOKEN        # Automatically provided

# Optional but recommended
CODECOV_TOKEN       # Code coverage reporting
SNYK_TOKEN         # Snyk vulnerability scanning
SONAR_TOKEN        # SonarCloud analysis
DOCKERHUB_USERNAME  # Docker Hub publishing
DOCKERHUB_TOKEN    # Docker Hub authentication
SLACK_WEBHOOK_URL  # Slack notifications
NVD_API_KEY        # NVD vulnerability database
DATREE_TOKEN       # Datree policy checks
GITLEAKS_LICENSE   # Gitleaks enhanced features
```

## Workflow Triggers

| Trigger Type | Description | Workflows |
|-------------|-------------|-----------|
| **Push** | On code push to branches | Most CI workflows |
| **Pull Request** | On PR open/sync/review | Validation and testing |
| **Schedule** | Cron-based scheduling | Security, cleanup, benchmarks |
| **Tag** | On version tags | Release automation |
| **Manual** | workflow_dispatch | All workflows support this |

## Best Practices

### 1. **Caching Strategy**
- Go module caching
- Docker layer caching
- Dependency caching
- Build artifact caching

### 2. **Parallelization**
- Matrix builds for multiple versions
- Parallel job execution
- Concurrent testing

### 3. **Conditional Execution**
- Path filters to skip unnecessary runs
- Conditional steps based on context
- Smart PR automation

### 4. **Security**
- Minimal permissions
- Secret scanning
- Dependency updates
- Vulnerability scanning

## Monitoring

### Success Metrics
- **Target CI Time**: <10 minutes
- **Success Rate**: >95%
- **Coverage**: >70%
- **Security**: Zero critical vulnerabilities

### Key Performance Indicators
- Average workflow duration
- Success/failure rates
- Resource utilization
- Cost per workflow run

## Troubleshooting

### Common Issues

1. **Workflow Timeouts**
   - Check for infinite loops
   - Verify network connectivity
   - Review resource limits

2. **Permission Errors**
   - Verify GITHUB_TOKEN permissions
   - Check repository settings
   - Review workflow permissions

3. **Cache Misses**
   - Verify cache keys
   - Check cache size limits
   - Review cache restoration

4. **Test Failures**
   - Check for race conditions
   - Verify test data
   - Review environment variables

## Local Testing

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act

# List available workflows
act -l

# Run specific workflow
act -W .github/workflows/api-gateway-ci.yml

# Run with specific event
act pull_request -W .github/workflows/pr-automation.yml
```

## Contributing

When adding new workflows:

1. Follow naming convention: `feature-name.yml`
2. Include comprehensive documentation
3. Add status badge to README
4. Update dashboard workflow
5. Consider cost implications
6. Add to cleanup routine if needed

## Cost Optimization

### Tips to Reduce Costs
1. Use conditional workflows
2. Implement effective caching
3. Optimize matrix strategies
4. Use workflow_run for chaining
5. Clean up artifacts regularly
6. Consider self-hosted runners for high-volume

## Support

- View all workflows: [Actions Tab](../../actions)
- Check security alerts: [Security Tab](../../security)
- Review insights: [Insights Tab](../../pulse)
- Report issues: [Issues Tab](../../issues)

---

*Last updated: 2025*
*Maintained by: Platform Team*