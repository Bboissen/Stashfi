#!/usr/bin/env bash
set -Eeuo pipefail

# Local helper to lint, template, and install Helm charts into a Kind cluster (like CI).

CHART_PATH=${CHART_PATH:-infra/helm/kong}
RELEASE=${RELEASE:-test-kong}
NAMESPACE=${NAMESPACE:-test}
K8S_VERSION=${K8S_VERSION:-1.31.3}
CLUSTER_NAME=${CLUSTER_NAME:-helm-test}

command -v helm >/dev/null 2>&1 || { echo "[!] helm is required"; exit 1; }
command -v kind >/dev/null 2>&1 || { echo "[!] kind is required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "[!] kubectl is required"; exit 1; }

echo "[i] Helm lint"
helm lint "${CHART_PATH}"

echo "[i] Creating Kind cluster '${CLUSTER_NAME}' (k8s ${K8S_VERSION})"
kind create cluster --name "${CLUSTER_NAME}" --image "kindest/node:v${K8S_VERSION}" >/dev/null

cleanup() {
  echo "[i] Cleaning up Kind cluster '${CLUSTER_NAME}'"
  kind delete cluster --name "${CLUSTER_NAME}" >/dev/null || true
}
trap cleanup EXIT

echo "[i] Installing chart ${RELEASE} in namespace ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" >/dev/null 2>&1 || true
helm install "${RELEASE}" "${CHART_PATH}" --namespace "${NAMESPACE}" --create-namespace

echo "[i] Upgrading chart ${RELEASE} (no-op upgrade to test path)"
helm upgrade "${RELEASE}" "${CHART_PATH}" --namespace "${NAMESPACE}"

echo "[i] Rolling back chart ${RELEASE} to revision 1"
helm rollback "${RELEASE}" 1 --namespace "${NAMESPACE}"

echo "[i] Uninstalling chart ${RELEASE}"
helm uninstall "${RELEASE}" --namespace "${NAMESPACE}"
kubectl delete namespace "${NAMESPACE}" >/dev/null || true

echo "[✓] Helm tests complete"
