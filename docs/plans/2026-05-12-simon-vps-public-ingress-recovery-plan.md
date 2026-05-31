# Simon VPS Public Ingress Recovery Plan

> For Hermes: treat this as an operator recovery plan. Do not call the site fixed until external checks pass from outside the VPS.

**Goal:** Make CloudToLocalLLM publicly reachable on Simon's VPS using a real domain path, not just a localhost-only compose deployment.

**Current verified state:**
- App stack is running on Simon's VPS (`31.97.140.7`) via Docker Compose.
- Local checks pass on the VPS:
  - `http://127.0.0.1:3100/health` → `200`
  - `http://127.0.0.1:3100/` → `200`
- Public path is broken because:
  - `app.cloudtolocalllm.online` and `api.cloudtolocalllm.online` resolve to `208.110.72.50`, not `31.97.140.7`
  - `cloudtolocalllm.online` does not resolve
  - Simon VPS does not expose 80/443
  - raw `31.97.140.7:3100` is not reachable from outside
  - `cloudflared` on Simon VPS is for a different service and CloudToLocalLLM has no active public ingress

**Architecture choice:**
Pick one public ingress path and finish it fully. Do not keep two half-configured paths alive. The realistic options are:
1. **Cloudflare Tunnel path** — preferred if DNS/Cloudflare access exists and raw VPS ports should stay closed.
2. **Direct DNS + reverse proxy path** — only if DNS can point to `31.97.140.7` and network policy allows public 80/443.

---

## Decision gate

Before touching config, decide which path is intended:

### Option A — Cloudflare Tunnel
Use when:
- we want stable HTTPS without opening raw public ports
- we have access to the correct Cloudflare zone/account for `cloudtolocalllm.online`

### Option B — Direct public reverse proxy
Use when:
- DNS can be changed to `31.97.140.7`
- 80/443 can be opened and routed on the VPS
- we want no Cloudflare tunnel dependency

If this decision is not made, the deployment will stay in split-brain mode.

---

## Phase 1: Preserve and document current state

### Task 1.1: Snapshot live VPS config
**Files / surfaces:**
- `/opt/cloudtolocalllm/deploy/simon-vps/.env`
- `/opt/cloudtolocalllm/deploy/simon-vps/docker-compose.yml`
- `/opt/cloudtolocalllm/deploy/simon-vps/nginx.conf`
- `/etc/cloudflared/config.yml`
- `systemctl cat cloudflared`

**Commands:**
```bash
ssh root@31.97.140.7 '
  mkdir -p /root/cloudtolocalllm-recovery-snapshots/$(date +%Y%m%d-%H%M%S) &&
  SNAP=$(ls -td /root/cloudtolocalllm-recovery-snapshots/* | head -1) &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/.env "$SNAP/.env" &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/docker-compose.yml "$SNAP/docker-compose.yml" &&
  cp /opt/cloudtolocalllm/deploy/simon-vps/nginx.conf "$SNAP/nginx.conf" &&
  cp /etc/cloudflared/config.yml "$SNAP/cloudflared-config.yml" 2>/dev/null || true &&
  systemctl cat cloudflared > "$SNAP/cloudflared.service.txt" 2>/dev/null || true &&
  echo "$SNAP"'
```

**Success criteria:** snapshot path printed and files copied.

---

## Phase 2: Fix the public routing model

## Path A — Cloudflare Tunnel recovery

### Task 2A.1: Recover or obtain the correct Cloudflare tunnel ownership
**Objective:** prove we have the right Cloudflare account/token for `cloudtolocalllm.online`.

**Checks:**
- verify who controls DNS for `cloudtolocalllm.online`
- verify whether an existing tunnel already exists for this project
- verify the current `cloudflared` service is not reused from ImmoGestion

**Commands:**
```bash
ssh root@31.97.140.7 'sed -n "1,200p" /etc/cloudflared/config.yml; systemctl cat cloudflared'
```

**Expected now:** current service is unrelated and disabled for CloudToLocalLLM.

### Task 2A.2: Define CloudToLocalLLM tunnel ingress
**Target mapping:**
- `app.cloudtolocalllm.online` → `http://127.0.0.1:3100`
- `api.cloudtolocalllm.online` → either:
  - same `http://127.0.0.1:3100` if nginx is the single public front door, or
  - `http://127.0.0.1:3000` only if we intentionally expose API separately

**Preferred shape:** single front door through nginx on `3100`.

**Config example:**
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

### Task 2A.3: Run Cloudflared as a CloudToLocalLLM-specific service
Do not overload the ImmoGestion service unit.

**Files:**
- create `/etc/cloudflared/cloudtolocalllm.yml`
- create `/etc/systemd/system/cloudflared-cloudtolocalllm.service`

**Success criteria:** separate service name, separate tunnel config, separate credentials.

### Task 2A.4: Verify tunnel path end-to-end
**Commands:**
```bash
ssh root@31.97.140.7 'systemctl restart cloudflared-cloudtolocalllm && systemctl status cloudflared-cloudtolocalllm --no-pager -l | sed -n "1,80p"'

curl -I -L https://app.cloudtolocalllm.online
curl -I -L https://api.cloudtolocalllm.online/health
```

**Success criteria:**
- app returns `200`
- api health returns `200`
- no more public `500` from the stale target

---

## Path B — Direct DNS + reverse proxy recovery

### Task 2B.1: Move DNS to Simon VPS
**Required DNS changes:**
- `app.cloudtolocalllm.online` → `31.97.140.7`
- `api.cloudtolocalllm.online` → `31.97.140.7`
- optional root/apex as desired

**Current problem:** those hosts currently resolve to `208.110.72.50`.

### Task 2B.2: Publish nginx on 80/443 instead of only 3100
**File:** `/opt/cloudtolocalllm/deploy/simon-vps/docker-compose.yml`

**Change:** publish proxy on 80/443, not just 3100, or add a host nginx/traefik layer forwarding 80/443 to 3100.

### Task 2B.3: Install TLS
Pick one:
- Let’s Encrypt on host nginx/traefik
- Caddy
- certbot-managed nginx

### Task 2B.4: Verify direct public path
**Commands:**
```bash
curl -I -L https://app.cloudtolocalllm.online
curl -I -L https://api.cloudtolocalllm.online/health
```

**Success criteria:** both return `200` against Simon VPS after DNS propagation.

---

## Phase 3: Remove split-brain/stale references

### Task 3.1: Stop serving stale public hosts from the wrong machine
Current public hosts point to `208.110.72.50` and return `500`.

**Required outcome:** once the chosen ingress path is live, the old target must no longer answer those domains.

### Task 3.2: Align app config with the chosen public host
**Files to audit after ingress fix:**
- `deploy/simon-vps/.env`
- any Flutter web build defines used by `deploy/simon-vps/build-web.sh`
- any web config that hardcodes `api.cloudtolocalllm.online`

**Verification:**
- app loads in browser
- browser network requests go to the intended public host
- `/health` succeeds through the same host users will hit

---

## Phase 4: Final verification checklist

Do not mark complete until all of this is true.

### VPS-local checks
```bash
curl -sS -D - http://127.0.0.1:3100/health -o /tmp/health.out
curl -sS -D - http://127.0.0.1:3100/ -o /tmp/root.out
```
Expected: `200`, app HTML.

### DNS checks
```bash
getent ahosts app.cloudtolocalllm.online
getent ahosts api.cloudtolocalllm.online
```
Expected: resolve to the intended public target for the chosen ingress path.

### External checks
```bash
curl -I -L https://app.cloudtolocalllm.online
curl -I -L https://api.cloudtolocalllm.online/health
```
Expected: `200`.

### Browser check
Use a real browser or browser automation and verify:
- app page renders
- no generic 500 page
- no DNS error
- API requests succeed

---

## Most likely fastest fix
Based on current evidence, the fastest realistic recovery is:
1. **use Cloudflare Tunnel**, not raw port exposure
2. create a **CloudToLocalLLM-specific cloudflared service** on Simon VPS
3. point `app.cloudtolocalllm.online` and `api.cloudtolocalllm.online` at that tunnel
4. stop relying on `208.110.72.50`

Reason:
- Simon VPS already has no working 80/443 path for this app
- raw `:3100` is not externally reachable
- cloudflared already exists on-box, but currently for the wrong service
- DNS is already split and stale, so trying to salvage the current public path without choosing one ingress model will keep failing

---

## Operator report format
When executing this plan, report in this exact structure:
- **Chosen ingress model:** Cloudflare tunnel / direct DNS
- **Old public target:** what DNS pointed to before
- **New public target:** what DNS/tunnel points to now
- **Local VPS health:** pass/fail
- **External app URL check:** pass/fail
- **External API health check:** pass/fail
- **Remaining blocker:** none / exact blocker
