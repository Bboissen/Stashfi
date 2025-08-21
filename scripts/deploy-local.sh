#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Stashfi local deployment..."

# Check if mise is installed
if ! command -v mise &> /dev/null; then
    echo "📦 Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install required tools via mise
cd "$PROJECT_ROOT"
echo "📦 Installing tools from mise.toml..."

# Install tools from mise.toml
mise install

# Activate mise environment
eval "$(mise activate bash)"

# Verify tools are available
echo "✅ Tool versions:"
mise list | grep -E "go|helm|kubectl|minikube" || true

echo "📦 Checking minikube status..."
if ! minikube status &> /dev/null; then
    echo "🔧 Starting minikube..."
    minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.31.0
else
    echo "✅ minikube is already running"
fi

eval "$(minikube docker-env)"

echo "🏗️ Building API Gateway Docker image..."
docker build -t stashfi/api-gateway:latest "$PROJECT_ROOT/services/api-gateway"

echo "📦 Creating stashfi namespace..."
kubectl create namespace stashfi --dry-run=client -o yaml | kubectl apply -f -

echo "🔄 Updating Helm dependencies for Kong..."
cd "$PROJECT_ROOT/infra/helm/kong"
helm dependency update

echo "📦 Installing Kong API Gateway..."
helm upgrade --install kong . \
    --namespace stashfi \
    --create-namespace \
    --wait \
    --timeout 5m

echo "🚀 Deploying API Gateway service..."
kubectl apply -f "$PROJECT_ROOT/infra/k8s/api-gateway-deployment.yaml" -n stashfi

echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n stashfi --timeout=60s || true

echo "📊 Deployment status:"
kubectl get pods -n stashfi

echo ""
echo "📌 Access endpoints:"
echo "🌐 Kong Proxy: http://$(minikube ip):32080"
echo "🌐 Kong Proxy (HTTPS): https://$(minikube ip):32443"
echo ""
echo "🔒 Kong Admin API (ClusterIP - use port-forward for access):"
echo "   kubectl port-forward -n stashfi service/kong-kong-admin 8001:8001"
echo "   Then access at: http://localhost:8001"

echo "✅ Local deployment complete!"
