#!/usr/bin/env python3
import json
import os
import sys
import urllib.request

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

repos = {
    # Kubernetes & tooling
    "kubernetes-sigs/kind": "Kind",
    "helm/helm": "Helm",
    "yannh/kubeconform": "kubeconform",
    "FairwindsOps/pluto": "Pluto",
    # GitHub Actions
    "actions/checkout": "actions/checkout",
    "actions/setup-go": "actions/setup-go",
    "actions/upload-artifact": "actions/upload-artifact",
    "actions/download-artifact": "actions/download-artifact",
    "actions/cache": "actions/cache",
    "actions/github-script": "actions/github-script",
    "actions/labeler": "actions/labeler",
    "actions/attest-build-provenance": "actions/attest-build-provenance",
    "actions/dependency-review-action": "actions/dependency-review-action",
    "codecov/codecov-action": "codecov/codecov-action",
    "github/codeql-action": "github/codeql-action",
    "docker/setup-buildx-action": "docker/setup-buildx-action",
    "docker/build-push-action": "docker/build-push-action",
    "docker/login-action": "docker/login-action",
    "docker/setup-qemu-action": "docker/setup-qemu-action",
    "docker/metadata-action": "docker/metadata-action",
    "golangci/golangci-lint-action": "golangci-lint-action",
    "hadolint/hadolint-action": "hadolint-action",
    "anchore/sbom-action": "anchore/sbom-action",
    "snyk/actions": "snyk/actions",
    "sigstore/cosign-installer": "cosign-installer",
    "azure/setup-kubectl": "azure/setup-kubectl",
    "azure/setup-helm": "azure/setup-helm",
    # Security tools / actions
    "aquasecurity/trivy-action": "Trivy action",
    "docker/scout-action": "Docker Scout action",
    "zricethezav/gitleaks": "Gitleaks",
    "gitleaks/gitleaks-action": "Gitleaks action",
    "trufflesecurity/trufflehog": "TruffleHog",
    "SonarSource/sonarcloud-github-action": "SonarCloud action",
    "bridgecrewio/checkov-action": "Checkov action",
    "securego/gosec": "Gosec",
    "golangci/golangci-lint": "golangci-lint",
    "sigstore/cosign": "Cosign",
    "slsa-framework/slsa-verifier": "SLSA Verifier",
    "anchore/syft": "Syft",
    "anchore/grype": "Grype",
    "sonatype-nexus-community/nancy": "Nancy",
    "google/osv-scanner": "OSV Scanner",
    # Dev tools
    "mikefarah/yq": "yq",
    "jqlang/jq": "jq",
    "openpolicyagent/opa": "OPA",
    "FairwindsOps/polaris": "Polaris",
    "wagoodman/dive": "Dive",
    "hadolint/hadolint": "Hadolint",
    "goodwithtech/dockle": "Dockle",
    "medyagh/setup-minikube": "setup-minikube",
    "helm/kind-action": "kind-action",
    "peter-evans/create-pull-request": "create-pull-request",
    "slackapi/slack-github-action": "slack-github-action",
    "softprops/action-gh-release": "action-gh-release",
    "benchmark-action/github-action-benchmark": "github-action-benchmark",
    "dependabot/fetch-metadata": "dependabot-fetch-metadata",
    "amannn/action-semantic-pull-request": "action-semantic-pull-request",
    # App dependencies
    "Kong/kong": "Kong",
    "Kong/charts": "Kong Helm Chart",
}

def gh_api(url: str):
    req = urllib.request.Request(url)
    if GITHUB_TOKEN:
        req.add_header("Authorization", f"Bearer {GITHUB_TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "stashfi-version-scanner")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

def latest_tag(owner_repo: str) -> str:
    # Try releases/latest first
    try:
        data = gh_api(f"https://api.github.com/repos/{owner_repo}/releases/latest")
        tag = data.get("tag_name")
        if tag:
            return tag
    except Exception:
        pass
    # Fallback: first tag in tags list
    try:
        data = gh_api(f"https://api.github.com/repos/{owner_repo}/tags?per_page=1")
        if isinstance(data, list) and data:
            return data[0].get("name", "")
    except Exception:
        pass
    return ""

def main():
    out = {}
    for repo, label in repos.items():
        try:
            tag = latest_tag(repo)
            out[label] = {"repo": repo, "latest": tag}
        except Exception as e:
            out[label] = {"repo": repo, "latest": "", "error": str(e)}
    json.dump(out, sys.stdout, indent=2)

if __name__ == "__main__":
    main()
