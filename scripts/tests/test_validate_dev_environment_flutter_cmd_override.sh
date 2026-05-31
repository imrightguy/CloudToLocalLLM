#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/docker/validate_dev_environment.sh"
WORKDIR="$(mktemp -d)"
BIN_DIR="$WORKDIR/bin"
LOG_FILE="$WORKDIR/flutter.log"
mkdir -p "$BIN_DIR"
export LOG_FILE

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat > "$BIN_DIR/flutter-custom" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'flutter-custom:%s:%s\n' "$1" "$*" >> "${LOG_FILE:?missing LOG_FILE}"
case "${1:-}" in
  --version)
    echo 'Flutter 3.24.0 • channel stable'
    ;;
  doctor)
    echo 'Doctor summary (to see all details, run flutter doctor -v)'
    ;;
  devices)
    echo 'Chrome • chrome • web-javascript'
    ;;
  *)
    echo 'ok'
    ;;
esac
EOF
chmod +x "$BIN_DIR/flutter-custom"

set +e
output="$({
  FLUTTER_CMD="$BIN_DIR/flutter-custom" bash -lc "source '$TARGET_SCRIPT'; check_flutter"
} 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "check_flutter failed unexpectedly" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if ! grep -Fq 'Flutter version: 3.24.0' <<<"$output"; then
  echo "Expected Flutter version output to be derived from FLUTTER_CMD" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if ! grep -Fq 'Flutter doctor check passed' <<<"$output"; then
  echo "Expected doctor check success output" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if ! grep -Fq 'Flutter web support is available' <<<"$output"; then
  echo "Expected web support success output" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if [[ $(grep -Fxc 'flutter-custom:--version:--version' "$LOG_FILE") -ne 1 ]]; then
  echo "Expected a single FLUTTER_CMD --version invocation" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'flutter-custom:doctor:doctor --machine' "$LOG_FILE") -ne 1 ]]; then
  echo "Expected a single FLUTTER_CMD doctor invocation" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

if [[ $(grep -Fxc 'flutter-custom:devices:devices' "$LOG_FILE") -ne 1 ]]; then
  echo "Expected a single FLUTTER_CMD devices invocation" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

echo "PASS: scripts/docker/validate_dev_environment.sh respects FLUTTER_CMD in check_flutter"
