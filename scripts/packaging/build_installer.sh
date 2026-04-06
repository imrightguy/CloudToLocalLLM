#!/bin/bash
# Generate install.sh from template with current version
# This script embeds update-daemon files as base64 heredocs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$SCRIPT_DIR/installer-template.sh"
OUTPUT="$PROJECT_ROOT/dist/linux/install.sh"
UPDATE_DAEMON_DIR="$SCRIPT_DIR/update-daemon"

# Get version from pubspec.yaml
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)

mkdir -p "$(dirname "$OUTPUT")"

echo "Generating installer script for v$VERSION..."

# Prepare embedded files as base64
echo "Embedding update-daemon files..."

UPDATED_B64=$(base64 -w0 "$UPDATE_DAEMON_DIR/cloudtolocalllm-updated")
UPDATED_SERVICE_B64=$(base64 -w0 "$UPDATE_DAEMON_DIR/cloudtolocalllm-updated.service")
UPDATED_TIMER_B64=$(base64 -w0 "$UPDATE_DAEMON_DIR/cloudtolocalllm-updated.timer")

# Create temporary file with embedded data
TEMP_FILE=$(mktemp)

# Read template and replace version placeholder + embed files
sed "s/INSTALL_VERSION=\"\"/INSTALL_VERSION=\"$VERSION\"/" "$TEMPLATE" > "$TEMP_FILE"

# Add embedded files after the shebang
{
    # Get the first line (shebang)
    head -n 1 "$TEMP_FILE"

    # Add embedded data marker and files
    echo ""
    echo "# ===== EMBEDDED FILES (base64 encoded) ====="
    echo "EMBEDDED_UPDATED='$UPDATED_B64'"
    echo "EMBEDDED_UPDATED_SERVICE='$UPDATED_SERVICE_B64'"
    echo "EMBEDDED_UPDATED_TIMER='$UPDATED_TIMER_B64'"
    echo "# ===== END EMBEDDED FILES ====="
    echo ""

    # Get the rest of the template (skip first line)
    tail -n +2 "$TEMP_FILE"
} > "$OUTPUT"

# Clean up temp file
rm -f "$TEMP_FILE"

chmod +x "$OUTPUT"

echo "✓ Generated: $OUTPUT"
echo "  Version: $VERSION"
echo "  Embedded files: cloudtolocalllm-updated, .service, .timer"
