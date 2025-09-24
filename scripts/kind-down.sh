#!/usr/bin/env bash
set -euo pipefail

# kind-down.sh: Tear down local Stashfi kind environment.
#
# Usage:
#   scripts/kind-down.sh [--name NAME] [--keep-cluster] [--keep-namespaces] [--remove-images] [--prune-docker]
#
# Defaults:
#   NAME = stashfi
#
# Flags:
#   --name NAME         Cluster name (default: stashfi)
#   --keep-cluster      Do not delete the kind cluster
#   --keep-namespaces   Do not delete namespaces/resources; only delete cluster if not kept
#   --remove-images     Remove local images built for this repo (safe set)
#   --prune-docker      Perform 'docker image prune -f' after removal
#
# Examples:
#   scripts/kind-down.sh
#   scripts/kind-down.sh --remove-images --prune-docker
#   scripts/kind-down.sh --keep-cluster --keep-namespaces   # just stop port-forwards

cluster_name="stashfi"
keep_cluster="false"
keep_namespaces="false"
remove_images="false"
prune_docker="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) cluster_name="$2"; shift 2 ;;
    --keep-cluster) keep_cluster="true"; shift ;;
    --keep-namespaces) keep_namespaces="true"; shift ;;
    --remove-images) remove_images="true"; shift ;;
    --prune-docker) prune_docker="true"; shift ;;
    -h|--help)
      sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

# Move to repo root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

echo "Stopping any Stashfi port-forwards (if running) ..."
if need_cmd pgrep && need_cmd pkill; then
  # api-gateway service forward
  pgrep -f "kubectl.*-n\s*stashfi.*port-forward.*api-gateway-service" >/dev/null 2>&1 && \
    pkill -f "kubectl.*-n\s*stashfi.*port-forward.*api-gateway-service" || true
  # kong admin forward
  pgrep -f "kubectl.*-n\s*kong.*port-forward.*stashfi-kong-kong-admin" >/dev/null 2>&1 && \
    pkill -f "kubectl.*-n\s*kong.*port-forward.*stashfi-kong-kong-admin" || true
fi

if [[ "$keep_namespaces" != "true" ]]; then
  if need_cmd helm; then
    echo "Uninstalling Helm release 'stashfi-kong' (namespace kong) ..."
    helm uninstall stashfi-kong -n kong >/dev/null 2>&1 || true
  fi

  if need_cmd kubectl; then
    echo "Deleting API Gateway manifests ..."
    kubectl delete -f infra/k8s/ --ignore-not-found >/dev/null 2>&1 || true

    echo "Deleting namespaces 'kong' and 'stashfi' ..."
    kubectl delete ns kong stashfi --ignore-not-found >/dev/null 2>&1 || true
  fi
fi

if [[ "$keep_cluster" != "true" ]]; then
  if need_cmd kind; then
    if kind get clusters 2>/dev/null | grep -qx "$cluster_name"; then
      echo "Deleting kind cluster kind-$cluster_name ..."
      kind delete cluster --name "$cluster_name" >/dev/null
    else
      echo "kind cluster kind-$cluster_name not found; skipping delete."
    fi
  else
    echo "kind not installed; skipping cluster deletion."
  fi
else
  echo "--keep-cluster set; not deleting the kind cluster."
fi

if [[ "$remove_images" == "true" ]]; then
  if need_cmd docker; then
    echo "Removing local images built for this repo ..."
    docker rmi -f stashfi/api-gateway:latest >/dev/null 2>&1 || true
    # Add additional repo images here as needed

    if [[ "$prune_docker" == "true" ]]; then
      echo "Pruning dangling Docker images ..."
      docker image prune -f >/dev/null 2>&1 || true
    fi
  else
    echo "docker not installed; skipping image removal."
  fi
else
  echo "Image removal skipped (use --remove-images to enable)."
fi

echo "Teardown complete."
