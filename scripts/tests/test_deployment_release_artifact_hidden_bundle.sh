#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"
WORK_DIR="$(mktemp -d)"
SRC_DIR="$WORK_DIR/bundle"
DST_DIR="$WORK_DIR/staging/cloudtolocalllm"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$SRC_DIR/.hidden-dir" "$DST_DIR"
cat > "$SRC_DIR/index.html" <<'EOF'
<!doctype html>
<html><body>ok</body></html>
EOF
cat > "$SRC_DIR/.hidden-file" <<'EOF'
HIDDEN-FILE
EOF
cat > "$SRC_DIR/.hidden-dir/marker" <<'EOF'
HIDDEN-DIR
EOF

if ! grep -Fq 'cp -a build/linux/x64/release/bundle/. "$STAGING_DIR/cloudtolocalllm/"' "$WORKFLOW_FILE"; then
  echo "deployment workflow missing cp -a bundle copy hardening" >&2
  exit 1
fi

cp -a "$SRC_DIR/." "$DST_DIR/"

for expected in "$DST_DIR/index.html" "$DST_DIR/.hidden-file" "$DST_DIR/.hidden-dir/marker"; do
  if [[ ! -f "$expected" ]]; then
    echo "missing copied bundle file: $expected" >&2
    find "$DST_DIR" -maxdepth 3 -print >&2
    exit 1
  fi
done

if ! grep -Fqx -- 'HIDDEN-FILE' "$DST_DIR/.hidden-file"; then
  echo "hidden file content was not preserved" >&2
  cat "$DST_DIR/.hidden-file" >&2
  exit 1
fi

if ! grep -Fqx -- 'HIDDEN-DIR' "$DST_DIR/.hidden-dir/marker"; then
  echo "hidden dir content was not preserved" >&2
  cat "$DST_DIR/.hidden-dir/marker" >&2
  exit 1
fi

echo "[test_deployment_release_artifact_hidden_bundle] Passed"
