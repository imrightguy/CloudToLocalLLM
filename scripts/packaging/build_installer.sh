#!/bin/bash
# Generate install.sh from template with current version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="$SCRIPT_DIR/installer-template.sh"
OUTPUT="$PROJECT_ROOT/dist/linux/install.sh"

# Get version from pubspec.yaml
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)

echo "Generating installer script for v$VERSION..."

# Read template and replace version placeholder
sed "s/INSTALL_VERSION=\"\"/INSTALL_VERSION=\"$VERSION\"/" "$TEMPLATE" > "$OUTPUT"

chmod +x "$OUTPUT"

echo "✓ Generated: $OUTPUT"
echo "  Version: $VERSION"
