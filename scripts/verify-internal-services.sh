#!/bin/bash
# Internal service verification script for CloudToLocalLLM
# This script should be run from within the cluster or a pod with network access.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SERVICES=(
  "api-backend.cloudtolocalllm.svc.cluster.local:8080/health"
  "web.cloudtolocalllm.svc.cluster.local:8080/health"
  "streaming-proxy.cloudtolocalllm.svc.cluster.local:3001/health"
  "grafana.cloudtolocalllm.svc.cluster.local:3000/api/health"
)

echo "Starting internal service verification..."

for SVC in "${SERVICES[@]}"; do
  echo -n "Checking http://$SVC... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$SVC")
  if [ "$STATUS" -eq 200 ]; then
    echo -e "${GREEN}OK (200)${NC}"
  else
    echo -e "${RED}FAILED ($STATUS)${NC}"
  fi
done

echo "Verification complete."
