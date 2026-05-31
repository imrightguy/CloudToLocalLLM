#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SIMON_HOST="${SIMON_HOST:-}"
SIMON_USER="${SIMON_USER:-root}"
SIMON_SSH_KEY_FILE="${SIMON_SSH_KEY_FILE:-}"
SIMON_APP_DIR="${SIMON_APP_DIR:-/opt/cloudtolocalllm}"
SIMON_PUBLIC_HTTP_PORT="${SIMON_PUBLIC_HTTP_PORT:-3100}"
CLOUDFLARE_DOMAIN="${CLOUDFLARE_DOMAIN:-cloudtolocalllm.online}"
CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-35fa09929e656c4e96e4aa79909d11b7}"
CLOUDFLARE_TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400}"
SYNC_REPO="${SYNC_REPO:-true}"
DEPLOY_APP="${DEPLOY_APP:-true}"
RECONCILE_CLOUDFLARE="${RECONCILE_CLOUDFLARE:-true}"
VERIFY_PUBLIC="${VERIFY_PUBLIC:-true}"
USE_PREBUILT_WEB="${USE_PREBUILT_WEB:-false}"

log() {
  printf '[deploy-simon-vps] %s\n' "$1"
}

fail() {
  printf '[deploy-simon-vps] ERROR: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

bool_is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

ssh_target() {
  printf '%s@%s' "$SIMON_USER" "$SIMON_HOST"
}

ssh_opts=(
  -i "$SIMON_SSH_KEY_FILE"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=6
)

remote_bash() {
  ssh "${ssh_opts[@]}" "$(ssh_target)" 'bash -seuo pipefail' "$@"
}

require_cmd ssh
require_cmd scp
require_cmd rsync
require_cmd python3
require_cmd curl

if [[ -z "$SIMON_SSH_KEY_FILE" ]]; then
  fail "SIMON_SSH_KEY_FILE is required"
fi
if [[ ! -f "$SIMON_SSH_KEY_FILE" ]]; then
  fail "SIMON_SSH_KEY_FILE does not exist: $SIMON_SSH_KEY_FILE"
fi
if [[ -z "$SIMON_HOST" ]]; then
  fail "SIMON_HOST is required"
fi

if bool_is_true "$RECONCILE_CLOUDFLARE"; then
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    fail "CLOUDFLARE_API_TOKEN is required when RECONCILE_CLOUDFLARE=true"
  fi
fi

TMPDIR_ROOT="${TMPDIR:-/tmp}"
TOKEN_ENV_FILE="$(mktemp "$TMPDIR_ROOT/cloudflared-env.XXXXXX")"
CF_SUMMARY_FILE="$(mktemp "$TMPDIR_ROOT/cloudflare-summary.XXXXXX")"
cleanup() {
  rm -f "$TOKEN_ENV_FILE" "$CF_SUMMARY_FILE"
}
trap cleanup EXIT

if bool_is_true "$SYNC_REPO"; then
  log "Syncing repository to Simon VPS: $(ssh_target):$SIMON_APP_DIR"
  rsync_args=(
    -az
    --delete
    --filter='P deploy/simon-vps/.env'
    --exclude '.git/'
    --exclude '.github/'
    --exclude '.dart_tool/'
    --exclude '.hermes/'
    --exclude '.kilo/'
    --exclude 'node_modules/'
    --exclude 'terminated'
  )
  if ! bool_is_true "$USE_PREBUILT_WEB"; then
    rsync_args+=(--exclude 'build/')
  fi
  rsync "${rsync_args[@]}" \
    -e "ssh ${ssh_opts[*]}" \
    "$REPO_ROOT/" "$(ssh_target):$SIMON_APP_DIR/"
fi

if bool_is_true "$DEPLOY_APP"; then
  log "Deploying Docker Compose stack on Simon VPS"
  remote_bash <<REMOTE
mkdir -p /root/cloudtolocalllm-recovery-snapshots
SNAP="/root/cloudtolocalllm-recovery-snapshots/\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$SNAP"
cd "$SIMON_APP_DIR"
if [[ -f deploy/simon-vps/.env ]]; then cp deploy/simon-vps/.env "\$SNAP/.env"; fi
cp deploy/simon-vps/docker-compose.yml "\$SNAP/docker-compose.yml"
cp deploy/simon-vps/nginx.conf "\$SNAP/nginx.conf"
test -f deploy/simon-vps/.env
if [[ "$USE_PREBUILT_WEB" == "true" ]]; then
  test -f build/web/index.html
else
  chmod +x deploy/simon-vps/build-web.sh
  ./deploy/simon-vps/build-web.sh
fi
cd deploy/simon-vps
docker compose --env-file .env up -d --build
docker compose ps
for attempt in \$(seq 1 24); do
  if curl -fsS "http://127.0.0.1:$SIMON_PUBLIC_HTTP_PORT/health" >/dev/null; then
    exit 0
  fi
  sleep 5
done
curl -fsS "http://127.0.0.1:$SIMON_PUBLIC_HTTP_PORT/health"
REMOTE
fi

if bool_is_true "$RECONCILE_CLOUDFLARE"; then
  log "Reconciling Cloudflare DNS and tunnel config"
  CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
  CLOUDFLARE_DOMAIN="$CLOUDFLARE_DOMAIN" \
  CLOUDFLARE_TUNNEL_ID="$CLOUDFLARE_TUNNEL_ID" \
  TOKEN_ENV_FILE="$TOKEN_ENV_FILE" \
  CF_SUMMARY_FILE="$CF_SUMMARY_FILE" \
  python3 <<'PY'
import json, os, ssl, urllib.request

api_token = os.environ['CLOUDFLARE_API_TOKEN'].strip()
account_id = os.environ['CLOUDFLARE_ACCOUNT_ID'].strip()
domain = os.environ['CLOUDFLARE_DOMAIN'].strip()
tunnel_id = os.environ['CLOUDFLARE_TUNNEL_ID'].strip()
token_env_file = os.environ['TOKEN_ENV_FILE']
summary_file = os.environ['CF_SUMMARY_FILE']
base = 'https://api.cloudflare.com/client/v4'
headers = {
    'Authorization': f'Bearer {api_token}',
    'Content-Type': 'application/json',
    'User-Agent': 'cloudtolocalllm-simon-vps-deploy'
}
ctx = ssl.create_default_context()

def api(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60, context=ctx) as resp:
        out = json.load(resp)
    if not out.get('success'):
        raise RuntimeError(f"Cloudflare API call failed for {path}: {out}")
    return out['result']

zone = api('GET', f'/zones?name={domain}')
if not zone:
    raise RuntimeError(f'No zone found for {domain}')
zone_id = zone[0]['id']

ingress = [
    {'hostname': f'api.{domain}', 'service': 'http://127.0.0.1:3100'},
    {'hostname': f'app.{domain}', 'service': 'http://127.0.0.1:3100'},
    {'hostname': domain, 'service': 'http://127.0.0.1:3100'},
    {'service': 'http_status:404'},
]
config = api('PUT', f'/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations', {
    'config': {
        'ingress': ingress,
        'warp-routing': {'enabled': False},
    }
})
records = api('GET', f'/zones/{zone_id}/dns_records?per_page=100')
by_name = {record['name']: record for record in records}
target = f'{tunnel_id}.cfargotunnel.com'
mutations = []
for name in [domain, f'app.{domain}', f'api.{domain}']:
    payload = {'type': 'CNAME', 'name': name, 'content': target, 'proxied': True, 'ttl': 1}
    current = by_name.get(name)
    if current:
        record = api('PUT', f"/zones/{zone_id}/dns_records/{current['id']}", payload)
        mutations.append({'action': 'updated', 'name': name, 'id': record['id']})
    else:
        record = api('POST', f'/zones/{zone_id}/dns_records', payload)
        mutations.append({'action': 'created', 'name': name, 'id': record['id']})
for record in records:
    if record['name'] == f'*.{domain}' and record['type'] == 'A' and record['content'] == '208.110.72.50':
        api('DELETE', f"/zones/{zone_id}/dns_records/{record['id']}")
        mutations.append({'action': 'deleted', 'name': record['name'], 'id': record['id']})

tunnel_token = api('GET', f'/accounts/{account_id}/cfd_tunnel/{tunnel_id}/token')
with open(token_env_file, 'w', encoding='utf-8') as handle:
    handle.write(f'TUNNEL_TOKEN={tunnel_token}\n')
os.chmod(token_env_file, 0o600)
summary = {
    'zone_id': zone_id,
    'tunnel_id': tunnel_id,
    'tunnel_config_version': config.get('version'),
    'mutations': mutations,
}
with open(summary_file, 'w', encoding='utf-8') as handle:
    json.dump(summary, handle)
print(json.dumps(summary))
PY

  log "Installing Cloudflare tunnel service on Simon VPS"
  scp "${ssh_opts[@]}" "$TOKEN_ENV_FILE" "$(ssh_target):/tmp/cloudflared-cloudtolocalllm.env"
  scp "${ssh_opts[@]}" \
    "$REPO_ROOT/deploy/simon-vps/cloudflared-cloudtolocalllm.service" \
    "$REPO_ROOT/deploy/simon-vps/cloudtolocalllm.yml" \
    "$(ssh_target):/tmp/"
  remote_bash <<REMOTE
mkdir -p /root/cloudtolocalllm-recovery-snapshots
SNAP="/root/cloudtolocalllm-recovery-snapshots/\$(date +%Y%m%d-%H%M%S)-cloudflared"
mkdir -p "\$SNAP"
[[ -f /etc/default/cloudflared-cloudtolocalllm ]] && cp /etc/default/cloudflared-cloudtolocalllm "\$SNAP/" || true
[[ -f /etc/systemd/system/cloudflared-cloudtolocalllm.service ]] && cp /etc/systemd/system/cloudflared-cloudtolocalllm.service "\$SNAP/" || true
[[ -f /etc/cloudflared/cloudtolocalllm.yml ]] && cp /etc/cloudflared/cloudtolocalllm.yml "\$SNAP/" || true
install -d -m 755 /etc/cloudflared
install -m 600 /tmp/cloudflared-cloudtolocalllm.env /etc/default/cloudflared-cloudtolocalllm
install -m 644 /tmp/cloudflared-cloudtolocalllm.service /etc/systemd/system/cloudflared-cloudtolocalllm.service
install -m 644 /tmp/cloudtolocalllm.yml /etc/cloudflared/cloudtolocalllm.yml
rm -f /tmp/cloudflared-cloudtolocalllm.env /tmp/cloudflared-cloudtolocalllm.service /tmp/cloudtolocalllm.yml
systemctl daemon-reload
systemctl enable --now cloudflared-cloudtolocalllm.service
systemctl is-active --quiet cloudflared-cloudtolocalllm.service
REMOTE
fi

if bool_is_true "$VERIFY_PUBLIC"; then
  log "Verifying tunnel health and public endpoints"
  if bool_is_true "$RECONCILE_CLOUDFLARE"; then
    CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
    CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
    CLOUDFLARE_TUNNEL_ID="$CLOUDFLARE_TUNNEL_ID" \
    python3 <<'PY'
import json, os, ssl, time, urllib.request
base = 'https://api.cloudflare.com/client/v4'
headers = {
    'Authorization': f"Bearer {os.environ['CLOUDFLARE_API_TOKEN'].strip()}",
    'Content-Type': 'application/json',
}
account_id = os.environ['CLOUDFLARE_ACCOUNT_ID'].strip()
tunnel_id = os.environ['CLOUDFLARE_TUNNEL_ID'].strip()
ctx = ssl.create_default_context()
for attempt in range(1, 13):
    req = urllib.request.Request(f'{base}/accounts/{account_id}/cfd_tunnel/{tunnel_id}', headers=headers)
    with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
        result = json.load(resp)['result']
    status = result.get('status')
    connections = len(result.get('connections', []))
    print(json.dumps({'attempt': attempt, 'status': status, 'connections': connections}))
    if status == 'healthy' and connections > 0:
        break
    time.sleep(5)
else:
    raise SystemExit('Tunnel never became healthy')
PY
  fi

  for url in \
    "https://$CLOUDFLARE_DOMAIN" \
    "https://app.$CLOUDFLARE_DOMAIN" \
    "https://api.$CLOUDFLARE_DOMAIN/health"
  do
    ok=false
    for attempt in $(seq 1 30); do
      status="$(curl -ksS -o /dev/null -w '%{http_code}' --max-time 20 "$url" || true)"
      if [[ "$status" == "200" ]]; then
        log "Verified $url -> 200"
        ok=true
        break
      fi
      sleep 10
    done
    if [[ "$ok" != true ]]; then
      fail "public verification failed for $url"
    fi
  done
fi

log "Simon VPS deployment workflow completed"
