#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/verify_github_release_assets.py"
WORK_DIR="$(mktemp -d)"
SERVER_LOG="$WORK_DIR/server.log"
SERVER_STATE="$WORK_DIR/state.json"
PORT_FILE="$WORK_DIR/port.txt"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$SERVER_STATE" <<'EOF'
{"assets": [
  {"name": "cloudtolocalllm-9.9.9-portable.zip"},
  {"name": "cloudtolocalllm-9.9.9-portable.zip.sha256"},
  {"name": "CloudToLocalLLM-Windows-9.9.9-Setup.exe"},
  {"name": "CloudToLocalLLM-Windows-9.9.9-Setup.exe.sha256"},
  {"name": "cloudtolocalllm_9.9.9_amd64.deb"},
  {"name": "cloudtolocalllm_9.9.9_amd64.deb.sha256"},
  {"name": "cloudtolocalllm-9.9.9-x86_64.AppImage"},
  {"name": "cloudtolocalllm-9.9.9-x86_64.AppImage.sha256"}
]}
EOF

python3 - <<'PY' "$SERVER_STATE" "$PORT_FILE" >"$SERVER_LOG" 2>&1 &
import json
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

state_path = Path(sys.argv[1])
port_path = Path(sys.argv[2])

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/repos/example-org/example-repo/releases/tags/v9.9.9":
            self.send_response(404)
            self.end_headers()
            return
        payload = state_path.read_text()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload.encode())))
        self.end_headers()
        self.wfile.write(payload.encode())

    def log_message(self, format, *args):
        pass

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]

server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
port_path.write_text(str(port))
server.serve_forever()
PY
SERVER_PID=$!

for _ in $(seq 1 50); do
  if [[ -s "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -s "$PORT_FILE" ]]; then
  echo "Test server failed to start" >&2
  cat "$SERVER_LOG" >&2
  exit 1
fi

PORT="$(cat "$PORT_FILE")"

GITHUB_TOKEN=dummy \
GITHUB_REPOSITORY=example-org/example-repo \
RELEASE_TAG=v9.9.9 \
VERSION=9.9.9 \
GITHUB_API_BASE_URL="http://127.0.0.1:$PORT" \
RETRY_ATTEMPTS=2 \
RETRY_DELAY_SECONDS=0 \
python3 "$SCRIPT_FILE" >"$WORK_DIR/script.log" 2>&1

if ! grep -Fq 'Verified GitHub release assets:' "$WORK_DIR/script.log"; then
  echo "Expected success output from release verifier" >&2
  cat "$WORK_DIR/script.log" >&2
  exit 1
fi

if ! grep -Fq 'CloudToLocalLLM-Windows-9.9.9-Setup.exe' "$WORK_DIR/script.log"; then
  echo "Expected installer name in verifier output" >&2
  cat "$WORK_DIR/script.log" >&2
  exit 1
fi

echo "[test_verify_github_release_assets_script] Passed"
