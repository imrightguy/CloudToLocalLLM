#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/full_release_wsl.sh"
WORK_DIR="$(mktemp -d)"
FAKE_ROOT="$WORK_DIR/fake-root"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/commands.log"
mkdir -p "$FAKE_ROOT/scripts/release" "$FAKE_ROOT/scripts/packaging" "$FAKE_BIN"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_ROOT/pubspec.yaml" <<'EOF'
name: temp_app
version: 7.8.9+10
EOF

cat > "$FAKE_ROOT/scripts/packaging/build_all_packages.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "linux-build $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/packaging/build_all_packages.sh"

cat > "$FAKE_ROOT/scripts/release/create_github_release.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "release $*" >> "$LOG_FILE"
exit 1
EOF
chmod +x "$FAKE_ROOT/scripts/release/create_github_release.sh"

cat > "$FAKE_BIN/wslpath" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" != "-w" ]]; then
  echo "expected -w" >&2
  exit 1
fi
echo 'C:\fake-root'
EOF
chmod +x "$FAKE_BIN/wslpath"

cat > "$FAKE_BIN/powershell.exe" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "windows $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/powershell.exe"

cat > "$FAKE_BIN/pacman" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "pacman $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/pacman"

cat > "$FAKE_BIN/which" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF
chmod +x "$FAKE_BIN/which"

cat > "$FAKE_BIN/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "sudo $*" >> "$LOG_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/sudo"

set +e
( cd "$PROJECT_ROOT" && PATH="$FAKE_BIN:$PATH" PROJECT_ROOT_OVERRIDE="$FAKE_ROOT" WINDOWS_BUILD_CMD="$FAKE_BIN/powershell.exe" WSLPATH_CMD="$FAKE_BIN/wslpath" PACMAN_CMD="$FAKE_BIN/pacman" SUDO_CMD="$FAKE_BIN/sudo" WHICH_CMD="$FAKE_BIN/which" bash scripts/release/full_release_wsl.sh ) > /tmp/test_full_release_wsl_project_root_override.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected full_release_wsl.sh to fail when release command fails" >&2
  cat /tmp/test_full_release_wsl_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'Current version: 7.8.9' /tmp/test_full_release_wsl_project_root_override.log; then
  echo "Missing version output" >&2
  cat /tmp/test_full_release_wsl_project_root_override.log >&2
  exit 1
fi

if ! grep -Fq 'windows -ExecutionPolicy Bypass -File C:\fake-root\scripts\powershell\Build-GitHubReleaseAssets.ps1 -InstallInnoSetup' "$LOG_FILE"; then
  echo "Windows command did not use PROJECT_ROOT_OVERRIDE" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'linux-build --skip-increment' "$LOG_FILE"; then
  echo "Linux build command was not invoked as expected" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'release ' "$LOG_FILE"; then
  echo "Release command was not invoked as expected" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if ! grep -Fq 'Failed to create GitHub release.' /tmp/test_full_release_wsl_project_root_override.log; then
  echo "Expected failure message from release stage" >&2
  cat /tmp/test_full_release_wsl_project_root_override.log >&2
  exit 1
fi

echo "[test_full_release_wsl_project_root_override] Passed"
