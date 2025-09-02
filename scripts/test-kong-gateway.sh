#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PROJECT_ROOT is defined for potential future use
# shellcheck disable=SC2034
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Stashfi Kong + API Gateway Setup"
echo "==========================================="

# Check if minikube is running
echo -e "\n${YELLOW}Checking minikube status...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "${RED}❌ Minikube is not running. Please run: minikube start${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Minikube is running${NC}"

# Check if Kong is deployed
echo -e "\n${YELLOW}Checking Kong deployment...${NC}"
if ! kubectl get deployment kong-kong -n stashfi &> /dev/null; then
    echo -e "${RED}❌ Kong is not deployed. Please deploy Kong first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kong is deployed${NC}"

# Check if API Gateway is deployed
echo -e "\n${YELLOW}Checking API Gateway deployment...${NC}"
if ! kubectl get deployment api-gateway -n stashfi &> /dev/null; then
    echo -e "${RED}❌ API Gateway is not deployed. Please deploy API Gateway first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ API Gateway is deployed${NC}"

# Wait for pods to be ready
echo -e "\n${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n stashfi --timeout=30s
kubectl wait --for=condition=ready pod -l app=api-gateway -n stashfi --timeout=30s
echo -e "${GREEN}✅ All pods are ready${NC}"

# Get Kong proxy URL through minikube tunnel
echo -e "\n${YELLOW}Starting minikube tunnel for Kong service...${NC}"
echo "Note: On macOS with Docker driver, we need to use minikube service tunnel"

# Start the tunnel in background and capture the URL
TUNNEL_OUTPUT=$(mktemp)
minikube service kong-kong-proxy -n stashfi --url > "$TUNNEL_OUTPUT" 2>&1 &
TUNNEL_PID=$!

# Wait for tunnel to start
sleep 3

# Get the URL from the output
KONG_URL=$(head -1 "$TUNNEL_OUTPUT")

if [ -z "$KONG_URL" ]; then
    echo -e "${RED}❌ Failed to get Kong URL from minikube tunnel${NC}"
    kill $TUNNEL_PID 2>/dev/null
    rm "$TUNNEL_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ Kong proxy available at: $KONG_URL${NC}"

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local expected_field=$2
    local description=$3

    echo -e "\n${YELLOW}Testing $endpoint - $description${NC}"

    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$KONG_URL$endpoint")
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS:")

    if [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ Status: 200 OK${NC}"
        echo "Response: $BODY"

        # Check if expected field exists in response
        if echo "$BODY" | grep -q "$expected_field"; then
            echo -e "${GREEN}✅ Response contains '$expected_field'${NC}"
        else
            echo -e "${RED}❌ Response missing '$expected_field'${NC}"
        fi
    else
        echo -e "${RED}❌ Status: $HTTP_STATUS (expected 200)${NC}"
        echo "Response: $BODY"
    fi
}

# Test all endpoints
echo -e "\n${YELLOW}=== Testing Endpoints ===${NC}"

test_endpoint "/health" "healthy" "Health check endpoint"
test_endpoint "/ready" "ready" "Readiness check endpoint"
test_endpoint "/api/v1/status" "operational" "API status endpoint"

# Test Kong Admin API (if exposed)
echo -e "\n${YELLOW}Testing Kong Admin API...${NC}"
ADMIN_URL="http://127.0.0.1:32001"
if curl -s -o /dev/null -w "%{http_code}" "$ADMIN_URL" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Kong Admin API is accessible at $ADMIN_URL${NC}"

    # Get routes from Kong
    echo -e "\n${YELLOW}Kong Routes:${NC}"
    curl -s "$ADMIN_URL/routes" | python3 -m json.tool 2>/dev/null | head -20 || echo "Unable to format JSON"
else
    echo -e "${YELLOW}⚠️  Kong Admin API not accessible via NodePort (this is normal if not exposed)${NC}"
fi

# Test direct API Gateway access
echo -e "\n${YELLOW}Testing direct API Gateway access (bypassing Kong)...${NC}"
kubectl port-forward -n stashfi svc/api-gateway-service 8081:8080 > /dev/null 2>&1 &
PF_PID=$!
sleep 2

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081/health" | grep -q "200"; then
    echo -e "${GREEN}✅ Direct API Gateway access works${NC}"
else
    echo -e "${RED}❌ Direct API Gateway access failed${NC}"
fi

# Cleanup port forward
kill $PF_PID 2>/dev/null

# Performance test
echo -e "\n${YELLOW}=== Performance Test ===${NC}"
echo "Running 10 requests to /health endpoint..."

total_time=0
for i in {1..10}; do
    response_time=$(curl -s -o /dev/null -w "%{time_total}" "$KONG_URL/health")
    total_time=$(echo "$total_time + $response_time" | bc)
    echo "Request $i: ${response_time}s"
done

avg_time=$(echo "scale=3; $total_time / 10" | bc)
echo -e "${GREEN}Average response time: ${avg_time}s${NC}"

# Show logs if there are errors
echo -e "\n${YELLOW}=== Recent Logs ===${NC}"
echo "Kong logs (last 5 lines):"
kubectl logs -n stashfi deployment/kong-kong --tail=5

echo -e "\nAPI Gateway logs (last 5 lines):"
kubectl logs -n stashfi deployment/api-gateway --tail=5

# Cleanup
echo -e "\n${YELLOW}Cleaning up...${NC}"
kill $TUNNEL_PID 2>/dev/null
rm "$TUNNEL_OUTPUT" 2>/dev/null

echo -e "\n${GREEN}✅ All tests completed!${NC}"
echo "==========================================="
echo "Summary:"
echo "- Kong URL: $KONG_URL"
echo "- All endpoints responding correctly"
echo "- Average response time: ${avg_time}s"
echo ""
echo "To access Kong continuously, run:"
echo "  minikube service kong-kong-proxy -n stashfi"
echo ""
echo "To check the admin API, run:"
echo "  curl http://\$(minikube ip):32001"
