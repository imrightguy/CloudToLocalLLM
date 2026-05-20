#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${CLOUDFLARE_DOMAIN:-cloudtolocalllm.online}"
TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400}"
TARGET_CNAME="${TUNNEL_ID}.cfargotunnel.com"

log_info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$1"; }
log_success() { printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$1"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1" >&2; }

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  log_error "CLOUDFLARE_API_TOKEN is mandatory"
  exit 1
fi

python3 <<'PY'
import json, os, ssl, urllib.request

domain = os.environ['DOMAIN']
tunnel_id = os.environ['TUNNEL_ID']
target_cname = os.environ['TARGET_CNAME']
api_token = os.environ['CLOUDFLARE_API_TOKEN'].strip()
base = 'https://api.cloudflare.com/client/v4'
headers = {
    'Authorization': f'Bearer {api_token}',
    'Content-Type': 'application/json',
    'User-Agent': 'cloudtolocalllm-cloudflare-dns-repair'
}
ctx = ssl.create_default_context()

def api(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60, context=ctx) as resp:
        body = json.load(resp)
    if not body.get('success'):
        raise RuntimeError(f'Cloudflare API failure for {path}: {body}')
    return body['result']

zone = api('GET', f'/zones?name={domain}')
if not zone:
    raise SystemExit(f'Zone not found for {domain}')
zone_id = zone[0]['id']
records = api('GET', f'/zones/{zone_id}/dns_records?per_page=100')
by_name = {record['name']: record for record in records}
mutations = []
for name in [domain, f'app.{domain}', f'api.{domain}']:
    payload = {
        'type': 'CNAME',
        'name': name,
        'content': target_cname,
        'proxied': True,
        'ttl': 1,
    }
    current = by_name.get(name)
    if current:
        result = api('PUT', f"/zones/{zone_id}/dns_records/{current['id']}", payload)
        mutations.append({'action': 'updated', 'name': name, 'id': result['id']})
    else:
        result = api('POST', f'/zones/{zone_id}/dns_records', payload)
        mutations.append({'action': 'created', 'name': name, 'id': result['id']})
for record in records:
    if record['name'] == f'*.{domain}' and record['type'] == 'A' and record['content'] == '208.110.72.50':
        api('DELETE', f"/zones/{zone_id}/dns_records/{record['id']}")
        mutations.append({'action': 'deleted', 'name': record['name'], 'id': record['id']})
print(json.dumps({'zone_id': zone_id, 'tunnel_id': tunnel_id, 'mutations': mutations}, indent=2))
PY

log_success "DNS stack aligned to ${TARGET_CNAME}"
