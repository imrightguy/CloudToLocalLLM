#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_SCRIPT="$PROJECT_ROOT/scripts/archive/deploy_to_vps.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BIN="$WORK_DIR/bin"
PROJECT_DIR="$WORK_DIR/project"
BACKUP_DIR="$WORK_DIR/backups"
mkdir -p "$FAKE_BIN" "$PROJECT_DIR/build/web" "$PROJECT_DIR/nginx" "$BACKUP_DIR"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$FAKE_BIN/date" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$*" == *"+%Y%m%d_%H%M%S"* ]]; then
  printf '%s\n' '20260512_090000'
else
  /bin/date "$@"
fi
EOF
chmod +x "$FAKE_BIN/date"

cat > "$PROJECT_DIR/build/web/index.html" <<'EOF'
<!doctype html>
<html>
  <body>web</body>
</html>
EOF

cat > "$PROJECT_DIR/build/web/.hidden-web" <<'EOF'
WEB-HIDDEN
EOF

mkdir -p "$PROJECT_DIR/build/web/.well-known/acme-challenge"
cat > "$PROJECT_DIR/build/web/.well-known/acme-challenge/token" <<'EOF'
TOKEN
EOF

cat > "$PROJECT_DIR/nginx/default.conf" <<'EOF'
server {}
EOF
cat > "$PROJECT_DIR/nginx/.hidden-nginx" <<'EOF'
NGINX-HIDDEN
EOF

if ! grep -Fq 'cp -a build/web "$backup_path/"' "$SOURCE_SCRIPT"; then
  echo "deployment script missing cp -a backup hardening for build/web" >&2
  exit 1
fi

if ! grep -Fq 'cp -a nginx "$backup_path/"' "$SOURCE_SCRIPT"; then
  echo "deployment script missing cp -a backup hardening for nginx" >&2
  exit 1
fi

set +e
PROJECT_DIR="$PROJECT_DIR" BACKUP_DIR="$BACKUP_DIR" PATH="$FAKE_BIN:$PATH" bash -c 'cd "$2"; source "$1"; create_backup' _ "$SOURCE_SCRIPT" "$PROJECT_DIR" > "$WORK_DIR/output.log" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "create_backup failed unexpectedly" >&2
  cat "$WORK_DIR/output.log" >&2
  exit 1
fi

backup_path="$BACKUP_DIR/backup_20260512_090000"
if [[ ! -d "$backup_path" ]]; then
  echo "backup directory was not created" >&2
  find "$BACKUP_DIR" -maxdepth 2 -type d >&2
  exit 1
fi

for expected in \
  "$backup_path/web/index.html" \
  "$backup_path/web/.hidden-web" \
  "$backup_path/web/.well-known/acme-challenge/token" \
  "$backup_path/nginx/default.conf" \
  "$backup_path/nginx/.hidden-nginx"
do
  if [[ ! -f "$expected" ]]; then
    echo "missing expected backup file: $expected" >&2
    find "$backup_path" -maxdepth 4 -print >&2
    exit 1
  fi
done

if ! grep -Fqx -- 'WEB-HIDDEN' "$backup_path/web/.hidden-web"; then
  echo "hidden web file content was not preserved" >&2
  cat "$backup_path/web/.hidden-web" >&2
  exit 1
fi

if ! grep -Fqx -- 'NGINX-HIDDEN' "$backup_path/nginx/.hidden-nginx"; then
  echo "hidden nginx file content was not preserved" >&2
  cat "$backup_path/nginx/.hidden-nginx" >&2
  exit 1
fi

echo "[test_deploy_to_vps_backup_hidden_files] Passed"
