# GitHub Secrets Configuration Guide

## Overview
The current GitHub Actions workflows run entirely with the built-in `GITHUB_TOKEN`. No additional repository secrets are required to execute the pipelines documented in `.github/workflows/`.

## When You Need Extra Secrets
Add secrets only when you extend workflows to integrate with external services. Common examples:
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` – push container images to Docker Hub instead of (or in addition to) GHCR.
- `CODECOV_TOKEN` – upload coverage results to Codecov from the Go CI job.
- `SNYK_TOKEN` – enable Snyk scans if you add that step to the security workflow.

## Adding a Repository Secret
1. Open **Settings → Secrets and variables → Actions**.
2. Select **New repository secret**.
3. Enter the secret name and value, then click **Add secret**.

Use environment or organization secrets if you need to scope credentials to specific branches or multiple repositories.

## Validating Secrets in a Workflow
Add a step like the snippet below whenever you introduce a new secret-dependent job:

```bash
if [ -z "${{ secrets.MY_SECRET }}" ]; then
  echo "Missing MY_SECRET – update repository secrets" >&2
  exit 1
fi
```

Document new requirements here whenever you expand the automation surface.
