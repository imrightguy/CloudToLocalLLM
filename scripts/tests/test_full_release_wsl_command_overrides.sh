#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/release/full_release_wsl.sh"
WORK_DIR="$(mktemp -d)"
REPO_DIR="$WORK_DIR/repo"
FAKE_BIN="$WORK_DIR/bin"
LOG_FILE="$WORK_DIR/commands.log"
mkdir -p "$REPO_DIR/scripts/release" "$REPO_DIR/scripts/packaging" "$FAKE_BIN"
export LOG_FILE

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp "$SOURCE_SCRIPT" "$REPO_DIR/scripts/release/full_release_wsl.sh"
chmod +x "$REPO_DIR/scripts/release/full_release_wsl.sh"

cat > "$REPO_DIR/pubspec.yaml" <<'EOF'
name: temp_app
version: 7.8.9+10
EOF

cat > "$REPO_DIR/scripts/packaging/build_all_packages.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "linux-build $*" >> "$LOG_FILE"
EOF
chmod +x "$REPO_DIR/scripts/packaging/build_all_packages.sh"

cat > "$REPO_DIR/scripts/release/create_github_release.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "release $*" >> "$LOG_FILE"
exit 1
EOF
chmod +x "$REPO_DIR/scripts/release/create_github_release.sh"

cat > "$FAKE_BIN/wslpath" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" != "-w" ]]; then
  echo "expected -w" >&2
  exit 1
fi
echo 'C:\repo'
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
( cd "$REPO_DIR" && PATH="$FAKE_BIN:$PATH" WINDOWS_BUILD_CMD=powershell.exe LINUX_BUILD_CMD="$REPO_DIR/scripts/packaging/build_all_packages.sh" RELEASE_CMD="$REPO_DIR/scripts/release/create_github_release.sh" WSLPATH_CMD=wslpath PACMAN_CMD=pacman SUDO_CMD=sudo WHICH_CMD=which bash scripts/release/full_release_wsl.sh ) > /tmp/test_full_release_wsl_command_overrides.log 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "Expected full_release_wsl.sh to fail when release command fails" >&2
  cat /tmp/test_full_release_wsl_command_overrides.log >&2
  exit 1
fi

if ! grep -Fq 'Current version: 7.8.9' /tmp/test_full_release_wsl_command_overrides.log; then
  echo "Missing version output" >&2
  cat /tmp/test_full_release_wsl_command_overrides.log >&2
  exit 1
fi

if ! grep -Fq 'windows -ExecutionPolicy Bypass -File C:\repo\scripts\powershell\Build-GitHubReleaseAssets.ps1 -InstallInnoSetup' "$LOG_FILE"; then
  echo "Windows command was not invoked as expected" >&2
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

if ! grep -Fq 'Failed to create GitHub release.' /tmp/test_full_release_wsl_command_overrides.log; then
  echo "Expected failure message from release stage" >&2
  cat /tmp/test_full_release_wsl_command_overrides.log >&2
  exit 1
fi

echo "[test_full_release_wsl_command_overrides] Passed"
