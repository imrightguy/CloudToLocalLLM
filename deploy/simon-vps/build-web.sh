#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PUBLIC_HTTP_PORT="${PUBLIC_HTTP_PORT:-3100}"
APP_ORIGIN="${APP_ORIGIN:-http://31.97.140.7:${PUBLIC_HTTP_PORT}}"
API_BASE_URL="${API_BASE_URL:-$APP_ORIGIN}"
ADMIN_SERVER_URL_WEB="${ADMIN_SERVER_URL_WEB:-$APP_ORIGIN}"
HOMEPAGE_URL="${HOMEPAGE_URL:-$APP_ORIGIN}"
APP_URL="${APP_URL:-$APP_ORIGIN}"
ADMIN_CENTER_URL="${ADMIN_CENTER_URL:-$APP_ORIGIN}"
TUNNEL_SSH_URL="${TUNNEL_SSH_URL:-ws://31.97.140.7:${PUBLIC_HTTP_PORT}/ssh}"
TUNNEL_SSH_URL_DEV="${TUNNEL_SSH_URL_DEV:-$TUNNEL_SSH_URL}"
FLUTTER_BUILD_IMAGE="${FLUTTER_BUILD_IMAGE:-instrumentisto/flutter:3.35.7}"
FLUTTER_CMD="${FLUTTER_CMD:-}"
if [[ -z "$FLUTTER_CMD" ]] && command -v flutter >/dev/null 2>&1; then
  FLUTTER_CMD="$(command -v flutter)"
fi

cd "$REPO_ROOT"
rm -rf build/web

if [[ -n "$FLUTTER_CMD" ]]; then
  "$FLUTTER_CMD" pub get
  "$FLUTTER_CMD" build web --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=ADMIN_SERVER_URL_WEB="$ADMIN_SERVER_URL_WEB" \
    --dart-define=HOMEPAGE_URL="$HOMEPAGE_URL" \
    --dart-define=APP_URL="$APP_URL" \
    --dart-define=ADMIN_CENTER_URL="$ADMIN_CENTER_URL" \
    --dart-define=TUNNEL_SSH_URL="$TUNNEL_SSH_URL" \
    --dart-define=TUNNEL_SSH_URL_DEV="$TUNNEL_SSH_URL_DEV"
else
  docker run --rm \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    "$FLUTTER_BUILD_IMAGE" \
    bash -lc "git config --global --add safe.directory /sdks/flutter && \
      git config --global --add safe.directory /workspace && \
      flutter pub get && flutter build web --release \
      --dart-define=API_BASE_URL=$API_BASE_URL \
      --dart-define=ADMIN_SERVER_URL_WEB=$ADMIN_SERVER_URL_WEB \
      --dart-define=HOMEPAGE_URL=$HOMEPAGE_URL \
      --dart-define=APP_URL=$APP_URL \
      --dart-define=ADMIN_CENTER_URL=$ADMIN_CENTER_URL \
      --dart-define=TUNNEL_SSH_URL=$TUNNEL_SSH_URL \
      --dart-define=TUNNEL_SSH_URL_DEV=$TUNNEL_SSH_URL_DEV && \
      chown -R \"\$HOST_UID:\$HOST_GID\" /workspace/build /workspace/.dart_tool /workspace/pubspec.lock"
fi
