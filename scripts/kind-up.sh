#!/usr/bin/env bash
set -euo pipefail

# kind-up.sh: Create a local kind cluster for Stashfi, load images, and apply manifests.
#
# Usage:
#   scripts/kind-up.sh [--name NAME] [--config PATH] [--recreate] [--build-image] [--install-kong]
#
# Defaults:
#   NAME    = stashfi
#   CONFIG  = infra/kind/kind-stashfi.yaml
#
# Examples:
#   scripts/kind-up.sh --build-image
#   scripts/kind-up.sh --recreate --install-kong

cluster_name="stashfi"
config_path="infra/kind/kind-stashfi.yaml"
recreate="false"
build_image="false"
install_kong="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      cluster_name="$2"; shift 2 ;;
    --config)
      config_path="$2"; shift 2 ;;
    --recreate)
      recreate="true"; shift ;;
    --build-image)
      build_image="true"; shift ;;
    --install-kong)
      install_kong="true"; shift ;;
    -h|--help)
      sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1" >&2
    echo "Hint: run 'mise install' to install tools from mise.toml" >&2
    exit 1
  fi
}

need_cmd kind
need_cmd kubectl
need_cmd docker

if [[ ! -f "$config_path" ]]; then
  echo "Config not found at $config_path" >&2
  exit 1
fi

if [[ "$recreate" == "true" ]]; then
  echo "Recreating cluster kind-$cluster_name ..."
  kind delete cluster --name "$cluster_name" || true
fi

if kind get clusters | grep -qx "$cluster_name"; then
  echo "Cluster kind-$cluster_name already exists. Skipping create."
else
  echo "Creating cluster kind-$cluster_name using $config_path ..."
  kind create cluster --name "$cluster_name" --config "$config_path"
fi

echo "Switching kubectl context to kind-$cluster_name ..."
kubectl config use-context "kind-$cluster_name" >/dev/null

if [[ "$build_image" == "true" ]]; then
  echo "Building API Gateway image ..."
  docker build -t stashfi/api-gateway:latest ./services/api-gateway
fi

echo "Loading image into kind ..."
kind load docker-image stashfi/api-gateway:latest --name "$cluster_name"

echo "Ensuring namespace 'stashfi' exists ..."
kubectl get ns stashfi >/dev/null 2>&1 || kubectl create namespace stashfi

echo "Applying Kubernetes manifests in infra/k8s ..."
kubectl apply -f infra/k8s/

if [[ "$install_kong" == "true" ]]; then
  need_cmd helm
  echo "Installing/Upgrading Kong chart ..."
  helm dependency build infra/helm/kong >/dev/null
  # Prefer a local override if present; fall back to bundled example
  values_file=""
  if [[ -f "infra/helm/kong/values.local.yaml" ]]; then
    values_file="infra/helm/kong/values.local.yaml"
  elif [[ -f "infra/helm/kong/values.local.yaml.example" ]]; then
    values_file="infra/helm/kong/values.local.yaml.example"
  fi

  if [[ -n "$values_file" ]]; then
    echo "Using values file: $values_file"
    helm upgrade --install stashfi-kong infra/helm/kong \
      --namespace kong --create-namespace \
      -f "$values_file"
  else
    echo "WARNING: No local Kong values override found; installing with chart defaults."
    echo "Proxy may not be exposed via NodePort on localhost without overrides."
    helm upgrade --install stashfi-kong infra/helm/kong \
      --namespace kong --create-namespace
  fi

  echo "Kong proxy will be available on http://localhost:32080 and https://localhost:32443 (when NodePort overrides are used)"
fi

echo "Done. Current pods in 'stashfi':"
kubectl get pods -n stashfi -o wide
