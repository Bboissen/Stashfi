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
    "github/codeql-action": "github/codeql-action",
    "docker/setup-buildx-action": "docker/setup-buildx-action",
    "docker/build-push-action": "docker/build-push-action",
    "docker/login-action": "docker/login-action",
    "docker/setup-qemu-action": "docker/setup-qemu-action",
    # Security tools
    "aquasecurity/trivy-action": "Trivy action",
    "zricethezav/gitleaks": "Gitleaks",
    "trufflesecurity/trufflehog": "TruffleHog",
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
    "GoogleContainerTools/container-structure-test": "Container Structure Test",
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
