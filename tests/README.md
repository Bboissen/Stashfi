# Tests Directory

This directory contains integration and end-to-end tests for the Stashfi platform.

## Structure

Tests are organized by service:
- `api-gateway/` - Tests for the API Gateway service
- Additional service test directories will be added as services are developed

## Running Tests

Integration tests can be run after deploying to minikube:
```bash
./scripts/deploy-local.sh
# Then run specific test suites
```

Each service should have its own unit tests within its service directory.
