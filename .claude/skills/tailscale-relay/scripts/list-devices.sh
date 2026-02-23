#!/bin/bash
# Tailscale Device Discovery Script
#
# Lists all Tailscale devices on your tailnet with their IPs, status, and OS
#
# Usage:
#   ./list-devices.sh
#   With formatting: ./list-devices.sh --json

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if tailscale is installed
if ! command -v tailscale &> /dev/null; then
  echo "❌ Error: Tailscale CLI not installed"
  echo ""
  echo "Install Tailscale:"
  echo "  Linux/Cloud:   curl -fsSL https://tailscale.com/install.sh | sh"
  echo "  macOS:         brew install tailscale"
  echo "  Windows:       Download from https://tailscale.com/download"
  exit 1
fi

# Parse arguments
output_format="table"
if [ "${1:-}" = "--json" ]; then
  output_format="json"
fi

echo "🌐 Tailscale Device Discovery"
echo "=============================="
echo ""

if [ "$output_format" = "json" ]; then
  log_info "Outputting JSON format..."
  tailscale status --json
else
  log_info "Retrieving devices from tailnet..."
  echo ""

  # Get JSON output from tailscale
  json_output=$(tailscale status --json 2>&1)

  if ! echo "$json_output" | jq empty 2>/dev/null; then
    echo "❌ Error: Failed to parse Tailscale output"
    echo "$json_output"
    exit 1
  fi

  # Display table header
  printf "${BLUE}%-25s %-20s %-15s %-10s${NC}\n" "HOSTNAME" "IP ADDRESS" "OS" "STATUS"
  echo "--------------------------------------------------------------------------------"

  # Parse and display each peer
  echo "$json_output" | jq -r '.Peer[] | @json' | while IFS= read -r peer; do
    hostname=$(echo "$peer" | jq -r '.HostName // "Unknown"')
    tailscale_ips=$(echo "$peer" | jq -r '.TailscaleIPs[0] // "N/A"')
    os=$(echo "$peer" | jq -r '.OS // "Unknown"')
    online=$(echo "$peer" | jq -r '.Online // false')

    if [ "$online" = "true" ]; then
      status="${GREEN}Online${NC}"
    else
      status="Offline"
    fi

    printf "%-25s %-20s %-15s %b\n" "$hostname" "$tailscale_ips" "$os" "$status"
  done

  echo ""
  echo "--------------------------------------------------------------------------------"

  # Summary statistics
  total_count=$(echo "$json_output" | jq -r '.Peer | length')
  online_count=$(echo "$json_output" | jq -r '[.Peer[] | select(.Online == true)] | length')

  echo ""
  log_info "Total devices: $total_count"
  log_info "Online devices: $online_count"
  echo ""

  # Show current machine info
  current_user=$(echo "$json_output" | jq -r '.Self.User // "Unknown"')
  current_name=$(echo "$json_output" | jq -r '.Self.HostName // "Unknown"')
  current_ip=$(echo "$json_output" | jq -r '.Self.TailscaleIPs[0] // "Unknown"')

  echo "📍 Current machine:"
  echo "   User: $current_user"
  echo "   Hostname: $current_name"
  echo "   Tailscale IP: $current_ip"
fi

echo ""
log_info "Done!"
