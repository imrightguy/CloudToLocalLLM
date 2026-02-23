#!/bin/bash
# Tailscale Relay WebSocket Connection Test
#
# Usage:
#   JWT_TOKEN=xxx TARGET_IP=100.100.100.100 ./test-connection.sh
#   RELAY_URL=ws://remote-relay:3002 JWT_TOKEN=xxx TARGET_IP=xxx ./test-connection.sh

set -euo pipefail

# Configuration
RELAY_URL="${RELAY_URL:-ws://localhost:3002/tailscale/ws}"
JWT_TOKEN="${JWT_TOKEN:-}"
TARGET_IP="${TARGET_IP:-}"
TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}ℹ${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

echo "🔌 Tailscale Relay WebSocket Test"
echo "=================================="
echo "Relay URL: $RELAY_URL"
echo ""

# Validate inputs
if [ -z "$JWT_TOKEN" ]; then
  log_error "JWT_TOKEN environment variable required"
  echo ""
  echo "Usage:"
  echo "  JWT_TOKEN=xxx TARGET_IP=100.100.100.100 ./test-connection.sh"
  echo ""
  echo "Generate a test JWT token:"
  echo "  node -e \"console.log(require('jsonwebtoken').sign({userId:'test'}, 'your-secret'))\""
  exit 1
fi

if [ -z "$TARGET_IP" ]; then
  log_warn "TARGET_IP not set, using test value"
  TARGET_IP="100.100.100.100"
fi

log_info "Target IP: $TARGET_IP"
echo ""

# Check for WebSocket testing tools
if command -v websocat &> /dev/null; then
  log_info "Using websocat for testing..."
  echo ""

  # Test payload for Ollama
  payload='{"model":"llama2","prompt":"Hello","stream":false}'

  log_info "Sending test payload: $payload"
  echo ""

  response=$(echo "$payload" | websocat -t --timeout="$TIMEOUT" "$RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP" 2>&1)

  if [ $? -eq 0 ]; then
    log_info "Connection successful!"
    echo ""
    echo "Response:"
    echo "$response"
  else
    log_error "Connection failed"
    echo "$response"
    exit 1
  fi

elif command -v wscat &> /dev/null; then
  log_info "Using wscat for testing..."
  echo ""

  # Create temporary script for wscat
  tmpfile=$(mktemp)
  echo '{"model":"llama2","prompt":"Hello","stream":false}' > "$tmpfile"

  log_info "Sending test payload..."
  echo ""

  cat "$tmpfile" | wscat -c "$RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP" || {
    log_error "Connection failed"
    rm -f "$tmpfile"
    exit 1
  }

  rm -f "$tmpfile"
  log_info "Connection successful!"

else
  log_warn "No WebSocket testing tool found"
  echo ""
  echo "Install one of the following:"
  echo "  websocat: cargo install websocat"
  echo "  wscat:    npm install -g wscat"
  echo ""
  echo "Manual test URL:"
  echo "  $RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP"
  echo ""
  echo "Test with browser WebSocket console:"
  echo "  const ws = new WebSocket('$RELAY_URL?token=$JWT_TOKEN&targetIp=$TARGET_IP');"
  echo "  ws.send(JSON.stringify({model:'llama2',prompt:'Hello'}));"
fi

echo ""
log_info "Test complete!"
