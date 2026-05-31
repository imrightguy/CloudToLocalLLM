#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_all_packages.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/project"
FAKE_VERSION_MANAGER="$FAKE_ROOT/scripts/version_manager.sh"
FAKE_LOG="$WORK_DIR/version-manager.log"
mkdir -p "$FAKE_ROOT/scripts"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_VERSION_MANAGER" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "version-manager invoked: $*" >> "$FAKE_LOG"
exit 0
EOF
chmod +x "$FAKE_VERSION_MANAGER"

set +e
PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" \
VERSION_MANAGER_SCRIPT="$FAKE_VERSION_MANAGER" \
bash "$TARGET_SCRIPT" > "$WORK_DIR/output.log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected build_all_packages.sh to fail when pubspec.yaml is missing" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if ! grep -Fq "pubspec.yaml not found" "$WORK_DIR/output.log"; then
  echo "Expected pubspec missing error message" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

if [[ -e "$FAKE_LOG" ]]; then
  echo "Version manager should not be invoked when pubspec.yaml is missing" >&2
  cat "$FAKE_LOG" >&2
  exit 1
fi

echo "[test_build_all_packages_missing_pubspec_guard] Passed"
