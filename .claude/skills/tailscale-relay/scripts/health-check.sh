#!/bin/bash
# Tailscale Relay Health Check Script
#
# Usage:
#   RELAY_URL=http://localhost:3002 ./health-check.sh
#   Or with defaults: ./health-check.sh

set -euo pipefail

# Configuration
RELAY_URL="${RELAY_URL:-http://localhost:3002}"
HEALTH_ENDPOINT="/health"
STATUS_ENDPOINT="/status"
TIMEOUT=5

echo "🔍 Tailscale Relay Health Check"
echo "================================"
echo "URL: $RELAY_URL"
echo ""

# Function to check endpoint
check_endpoint() {
  local url="$1"
  local name="$2"

  echo "Checking $name..."

  if ! command -v curl &> /dev/null; then
    echo "❌ Error: curl not installed"
    return 1
  fi

  if ! command -v jq &> /dev/null; then
    echo "⚠️  Warning: jq not installed (install for formatted output)"
    response=$(curl -s -m "$TIMEOUT" -w "\n%{http_code}" "$url" 2>&1)
  else
    response=$(curl -s -m "$TIMEOUT" -w "\n%{http_code}" "$url" 2>&1)
  fi

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -eq 200 ]; then
    if command -v jq &> /dev/null; then
      echo "✓ $name is healthy"
      echo "$body" | jq '.'
    else
      echo "✓ $name is healthy (HTTP $http_code)"
      echo "$body"
    fi
    return 0
  else
    echo "❌ $name check failed (HTTP $http_code)"
    echo "$body"
    return 1
  fi
}

# Main health check
exit_code=0

check_endpoint "$RELAY_URL$HEALTH_ENDPOINT" "Health Endpoint" || exit_code=1
echo ""
check_endpoint "$RELAY_URL$STATUS_ENDPOINT" "Status Endpoint" || exit_code=1

echo ""
if [ $exit_code -eq 0 ]; then
  echo "✅ All checks passed"
else
  echo "❌ Some checks failed"
fi

exit $exit_code
