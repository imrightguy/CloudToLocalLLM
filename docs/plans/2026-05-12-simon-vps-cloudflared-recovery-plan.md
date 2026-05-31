# Simon VPS Cloudflared Recovery Plan

> This replaces the generic ingress plan. The intended setup is Cloudflare Tunnel. Treat any direct-80/443 plan as wrong for this deployment.

**Goal:** Restore the public CloudToLocalLLM website on Simon's VPS by wiring the existing local compose stack to a dedicated Cloudflare Tunnel and correcting stale DNS/tunnel ownership drift.

**Verified current state:**
- Simon VPS: `31.97.140.7`
- Local stack is healthy on-box:
  - `http://127.0.0.1:3100/health` → `200`
  - `http://127.0.0.1:3100/` → `200`
- Public domains are broken:
  - `app.cloudtolocalllm.online` → resolves to `208.110.72.50`, returns `500`
  - `api.cloudtolocalllm.online` → resolves to `208.110.72.50`, returns `500`
  - `cloudtolocalllm.online` → does not resolve
- Simon VPS `cloudflared` is not serving CloudToLocalLLM:
  - current service is for ImmoGestion
  - `/etc/cloudflared/config.yml` is effectively disabled and ends in `http_status:404`
- Raw public port is not the intended path and is not reliably reachable from outside.

**Root cause class:** split-brain public ingress. The app is deployed locally, but the Cloudflare/DNS path was never finished or drifted to the wrong target.

---

## Success criteria

Do not call this fixed until all are true:
1. `https://app.cloudtolocalllm.online` returns `200`
2. `https://api.cloudtolocalllm.online/health` returns `200`
3. both hostnames route through a Cloudflare Tunnel tied to Simon VPS, not to `208.110.72.50`
4. the old broken public target no longer serves those names
5. browser renders the app and API calls succeed

---

## Phase 1: Snapshot and prove current drift

### Task 1.1: Snapshot live VPS ingress state
**Objective:** preserve the current broken state before changing it.

**Files / surfaces:**
- `/opt/cloudtolocalllm/deploy/simon-vps/.env`
- `/opt/cloudtolocalllm/deploy/simon-vps/docker-compose.yml`
- `/opt/cloudtolocalllm/deploy/simon-vps/nginx.conf`
- `/etc/cloudflared/config.yml`
- `systemctl cat cloudflared`

**Command:**
```bash
ssh -i ~/.ssh/immogestion_github_actions_ed25519 root@31.97.140.7 '
  mkdir -p /root/cloudtolocalllm-recovery-snapshots/$(date +%Y%m%d-%H%M%S) &&
  SNAP=$(ls -td /root/cloudtolocalllm-recovery-snapshots/* | head -1) &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/.env "$SNAP/.env" &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/docker-compose.yml "$SNAP/docker-compose.yml" &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/nginx.conf "$SNAP/nginx.conf" &&
  cp /etc/cloudflared/config.yml "$SNAP/cloudflared-config.yml" 2>/dev/null || true &&
  systemctl cat cloudflared > "$SNAP/cloudflared.service.txt" 2>/dev/null || true &&
  echo "$SNAP"'
```

**Verify:** snapshot path prints and copied files exist.

### Task 1.2: Record current public failure explicitly
**Objective:** capture the exact broken external state.

**Commands:**
```bash
curl -k -I -L https://app.cloudtolocalllm.online
curl -k -I -L https://api.cloudtolocalllm.online/health
getent ahosts app.cloudtolocalllm.online
getent ahosts api.cloudtolocalllm.online
```

**Expected now:**
- current A/edge path still points to the wrong public target
- app/api return `500` or otherwise fail

---

## Phase 2: Recover the correct Cloudflare ownership and tunnel material

### Task 2.1: Find or recover the right Cloudflare auth for `cloudtolocalllm.online`
**Objective:** stop guessing which account controls the zone.

**Method:** inspect prior Hermes/Paperclip/session artifacts for Cloudflare auth traces, then validate against Cloudflare API.

**Look for:**
- `X-Auth-Email`
- `X-Auth-Key`
- bearer token candidates
- zone references for `cloudtolocalllm.online`

**Validation commands:**
Legacy/global-key shape:
```bash
curl -sS "https://api.cloudflare.com/client/v4/zones?name=cloudtolocalllm.online" \
  -H "X-Auth-Email: <email>" \
  -H "X-Auth-Key: <key>"
```
Bearer shape:
```bash
curl -sS "https://api.cloudflare.com/client/v4/zones?name=cloudtolocalllm.online" \
  -H "Authorization: Bearer <token>"
```

**Success criteria:** one auth shape returns `success: true` and the actual zone/account.

### Task 2.2: List existing tunnel and DNS records for the zone
**Objective:** determine whether a CloudToLocalLLM tunnel already exists or whether DNS is just stale.

**Required queries:**
- list DNS records for:
  - `cloudtolocalllm.online`
  - `app.cloudtolocalllm.online`
  - `api.cloudtolocalllm.online`
- list tunnel-related records or current target mapping

**Success criteria:** exact current record set is captured before mutation.

---

## Phase 3: Create a dedicated CloudToLocalLLM tunnel on Simon VPS

### Task 3.1: Create a CloudToLocalLLM-specific cloudflared config
**Objective:** separate this from ImmoGestion completely.

**Create:** `/etc/cloudflared/cloudtolocalllm.yml`

**Target mapping:**
- `app.cloudtolocalllm.online` → `http://127.0.0.1:3100`
- `api.cloudtolocalllm.online` → `http://127.0.0.1:3100`
- optional apex redirect later, not in the first repair pass

**Config shape:**
```yaml
tunnel: <cloudtolocalllm-tunnel-id>
credentials-file: /etc/cloudflared/<cloudtolocalllm-tunnel-id>.json
ingress:
  - hostname: app.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - hostname: api.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - service: http_status:404
```

**Why single front door:** nginx on `3100` already knows how to route `/api`, `/v1`, `/health`, and `/` correctly.

### Task 3.2: Create a separate systemd unit
**Objective:** do not reuse the ImmoGestion tunnel service.

**Create:** `/etc/systemd/system/cloudflared-cloudtolocalllm.service`

**Minimal unit:**
```ini
[Unit]
Description=cloudflared CloudToLocalLLM tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared --config /etc/cloudflared/cloudtolocalllm.yml tunnel run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Verification:**
```bash
systemctl daemon-reload
systemctl enable --now cloudflared-cloudtolocalllm
systemctl status cloudflared-cloudtolocalllm --no-pager -l
journalctl -u cloudflared-cloudtolocalllm -n 100 --no-pager
```

**Success criteria:** service is active and tunnel registers successfully.

---

## Phase 4: Correct the Cloudflare DNS/tunnel routing

### Task 4.1: Point app/api hostnames at the Simon-VPS tunnel
**Objective:** remove the stale `208.110.72.50` route.

**Required outcome:**
- `app.cloudtolocalllm.online` no longer resolves/edges to the wrong public target
- `api.cloudtolocalllm.online` no longer resolves/edges to the wrong public target
- both are attached to the new Cloudflare Tunnel route for Simon VPS

**Important rule:** mutate records only after the Simon-VPS tunnel is up and verified locally.

### Task 4.2: Decide what to do with apex `cloudtolocalllm.online`
Current state: does not resolve.

First-pass recommendation:
- leave apex out of the first repair unless product explicitly needs it now
- get `app.` and `api.` green first
- then add apex as redirect or separate route later

---

## Phase 5: Verify end-to-end

### Task 5.1: Re-check local VPS path
**Commands:**
```bash
curl -sS -D - http://127.0.0.1:3100/health -o /tmp/ctllm-health.out
curl -sS -D - http://127.0.0.1:3100/ -o /tmp/ctllm-root.out
```
Expected: `200`.

### Task 5.2: Re-check DNS after Cloudflare mutation
**Commands:**
```bash
getent ahosts app.cloudtolocalllm.online
getent ahosts api.cloudtolocalllm.online
```
Also check with public DoH if needed.

**Expected:** no stale route to `208.110.72.50` for the repaired names.

### Task 5.3: Re-check public HTTP(S)
**Commands:**
```bash
curl -k -I -L https://app.cloudtolocalllm.online
curl -k -I -L https://api.cloudtolocalllm.online/health
```

**Expected:**
- app → `200`
- api health → `200`

### Task 5.4: Browser verification
**Objective:** verify real user path, not just curl.

**Check:**
- app page renders
- no Cloudflare 5xx page
- no generic Apache/Nginx 500 from stale host
- API requests succeed from the app

---

## Phase 6: Cleanup and anti-regression

### Task 6.1: Document the tunnel as the intended public path
**Files:**
- `deploy/simon-vps/README.md`
- any deployment notes that still imply raw public port access is the main path

### Task 6.2: Mark the stale route as retired
**Objective:** avoid future confusion.

Record in notes:
- old public target: `208.110.72.50`
- new public path: Cloudflare Tunnel on Simon VPS
- old raw `:3100` path is for local verification only, not the canonical public website path

---

## Fastest execution order
1. snapshot current state
2. recover valid Cloudflare auth for the correct zone
3. create Simon-VPS-specific CloudToLocalLLM tunnel config and service
4. verify tunnel process is healthy on the VPS
5. repoint `app.` and `api.` through that tunnel
6. verify externally with curl and browser
7. document the final routing so this does not drift again

---

## Operator report format
When the work is executed, report in this structure only:
- **Tunnel auth recovered:** yes/no
- **Zone/account confirmed:** yes/no + zone name
- **Dedicated CloudToLocalLLM cloudflared service:** active/inactive
- **Old public target removed:** yes/no
- **App URL external check:** pass/fail
- **API health external check:** pass/fail
- **Browser render:** pass/fail
- **Remaining blocker:** none / exact blocker
