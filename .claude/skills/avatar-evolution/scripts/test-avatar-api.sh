#!/bin/bash
# Test Avatar API Endpoints
#
# Usage: ./test-avatar-api.sh

set -euo pipefail

ROUTER_URL="${ROUTER_URL:-http://localhost:1337}"

echo "🧪 Avatar API Endpoint Tests"
echo "============================="
echo ""

# Check dependencies
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
  echo "❌ Error: curl and jq required"
  exit 1
fi

# Test counter
tests_passed=0
tests_failed=0

run_test() {
  local test_name="$1"
  local test_cmd="$2"
  local expected_code="${3:-200}"

  echo "Test: $test_name"
  response=$(eval "$test_cmd" 2>&1)
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  # Accept multiple success codes
  if echo "$expected_code" | grep -q "$http_code"; then
    echo "✓ PASSED (HTTP $http_code)"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    ((tests_passed++))
  else
    echo "✗ FAILED (HTTP $http_code, expected one of: $expected_code)"
    echo "$body"
    ((tests_failed++))
  fi
  echo ""
}

# Test 1: Get avatar state
run_test "GET /avatar/state" \
  "curl -s -w '\n%{http_code}' '$ROUTER_URL/avatar/state'" \
  "200"

# Test 2: Update personality traits
run_test "POST /avatar/traits" \
  "curl -s -w '\n%{http_code}' -X POST '$ROUTER_URL/avatar/traits' \
    -H 'Content-Type: application/json' \
    -d '{\"traits\":{\"formality\":0.5,\"humor\":0.5,\"enthusiasm\":0.5,\"empathy\":0.5}}'" \
  "200"

# Test 3: Request evolution (may fail with 400 if prerequisites not met)
run_test "POST /avatar/evolution/request" \
  "curl -s -w '\n%{http_code}' -X POST '$ROUTER_URL/avatar/evolution/request' \
    -H 'Content-Type: application/json' \
    -d '{\"stage\":\"knowledge_seeker\",\"reason\":\"Test evolution request\"}'" \
  "200 400"

# Summary
echo "============================="
echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
echo "============================="

if [ "$tests_failed" -eq 0 ]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
