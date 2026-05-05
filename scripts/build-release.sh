#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/release"

usage() {
  cat <<'EOF'
Usage: build-release.sh [OPTIONS]

Build ImmoGestion Flutter app for production.

Options:
  --apk        Build signed APK (default)
  --web        Build web version
  --all        Build both APK and web
  --skip-tests Skip running tests and analysis
  -h, --help   Show this help

Environment variables for APK signing:
  KEYSTORE_PATH       Path to Android keystore (.jks)
  KEYSTORE_PASSWORD   Keystore password
  KEY_ALIAS           Signing key alias
  KEY_PASSWORD        Key password

If signing env vars are missing, builds a debug APK instead.
EOF
  exit 0
}

MODE="apk"
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)   MODE="apk" ;;
    --web)   MODE="web" ;;
    --all)   MODE="all" ;;
    --skip-tests) SKIP_TESTS=true ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

cd "$PROJECT_ROOT"

resolve_flutter_bin() {
  local candidate
  for candidate in "${FLUTTER_BIN:-}" "/mnt/data/flutter-sdk/bin/flutter" "$(command -v flutter 2>/dev/null || true)"; do
    if [[ -n "${candidate:-}" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

FLUTTER_BIN_RESOLVED="$(resolve_flutter_bin)"
export FLUTTER_SUPPRESS_ANALYTICS="${FLUTTER_SUPPRESS_ANALYTICS:-true}"
export DART_SUPPRESS_ANALYTICS="${DART_SUPPRESS_ANALYTICS:-true}"

if [[ "$SKIP_TESTS" == "false" ]]; then
  echo "==> Running flutter analyze..."
  "$FLUTTER_BIN_RESOLVED" analyze --no-fatal-infos

  echo "==> Running tests..."
  "$FLUTTER_BIN_RESOLVED" test --reporter compact
fi

mkdir -p "$BUILD_DIR"

build_apk() {
  echo "==> Building APK..."

  if [[ -n "${KEYSTORE_PATH:-}" && -n "${KEYSTORE_PASSWORD:-}" && -n "${KEY_ALIAS:-}" && -n "${KEY_PASSWORD:-}" ]]; then
    echo "    Signed release build"
    "$FLUTTER_BIN_RESOLVED" build apk --release \
      --keystore-path="$KEYSTORE_PATH" \
      --keystore-password="$KEYSTORE_PASSWORD" \
      --key-alias="$KEY_ALIAS" \
      --key-password="$KEY_PASSWORD"
    cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/immogestion.apk"
  else
    echo "    No keystore configured — building debug APK"
    echo "    Set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD for signed builds"
    "$FLUTTER_BIN_RESOLVED" build apk --debug
    cp build/app/outputs/flutter-apk/app-debug.apk "$BUILD_DIR/immogestion-debug.apk"
  fi


  echo "    APK copied to $BUILD_DIR/"
}

build_web() {
  echo "==> Building web..."
  "$FLUTTER_BIN_RESOLVED" create . --platforms web
  "$FLUTTER_BIN_RESOLVED" build web --release --base-href '/' --dart-define=API_BASE_URL="${API_BASE_URL:-https://api.immogestion.app/api}"
  cp -r build/web "$BUILD_DIR/web"
  echo "    Web build copied to $BUILD_DIR/web/"
}

case "$MODE" in
  apk)  build_apk ;;
  web)  build_web ;;
  all)  build_apk; build_web ;;
esac

echo ""
echo "==> Build complete. Output in $BUILD_DIR/"
ls -lh "$BUILD_DIR"
