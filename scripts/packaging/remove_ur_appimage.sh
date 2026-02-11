#!/bin/bash
# Remove cloudtolocalllm-appimage from AUR
# This script should be run locally with AUR SSH access

set -e

echo "Removing cloudtolocalllm-appimage from AUR..."

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Clone the AUR repo
git clone ssh://aur@aur.archlinux.org/cloudtolocalllm-appimage.git aur-remove
cd aur-remove

# Remove all files to create an empty repo (marks package as deleted)
git rm -f PKGBUILD .SRCINFO 2>/dev/null || true

# Commit deletion
git config user.name "rightguy"
git config user.email "christopher.maltais@gmail.com"
git commit -m "Remove package - consolidated into cloudtolocalllm" || echo "Nothing to commit"

# Push to delete
git push origin master || echo "Push failed - may already be removed"

echo "AUR package removal complete"
cd /
rm -rf "$TMPDIR"
