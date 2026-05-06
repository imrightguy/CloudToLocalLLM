# ImmoGestion Backend - VPS Deployment Guide

Target: Hostinger VPS (31.97.140.7), Ubuntu 24.04, Docker with postgres.

## Prerequisites

1. SSH access to the VPS (ask Simon for credentials)
2. A Cloudflare account with the domain configured
3. GitHub repo access (already at https://github.com/imrightguy/ImmoGestion.git)
4. A GitHub PAT for GHCR pulls with `read:packages`, stored as the workflow secret `GHCR_TOKEN`

## Step 1: SSH Key Setup (first time only)

```bash
# From your local machine:
ssh-keygen -t ed25519 -C "immogestion-deploy" -f ~/.ssh/immogestion_deploy
ssh-copy-id -i ~/.ssh/immogestion_deploy.pub root@31.97.140.7

# Test:
ssh -i ~/.ssh/immogestion_deploy root@31.97.140.7 "echo OK"
```

## Step 2: VPS Preparation

```bash
ssh root@31.97.140.7

# Update system
apt update && apt upgrade -y

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker
docker --version

# Install docker compose (comes with modern Docker)
docker compose version

# Create app directory
mkdir -p /opt/immogestion
cd /opt/immogestion
```

## Step 3: Clone and Configure

```bash
cd /opt/immogestion

# Clone the repo
git clone https://github.com/imrightguy/ImmoGestion.git .
cd services/api-backend

# Create production env file
cp .env.production.template .env.production

# Edit .env.production with real values:
# - DB_PASSWORD (generate a strong one: openssl rand -base64 32)
# - JWT_SECRET (generate: openssl rand -base64 48)
# - JWT_REFRESH_SECRET (generate: openssl rand -base64 48)
# - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, SIMON_PHONE
# - SMTP settings (or leave empty for now)
# - CLOUDFLARE_TUNNEL_TOKEN (from Cloudflare dashboard)
# - DB_SSL=true (only if using an external database that requires SSL;
#   not needed for Docker-internal postgres connection)
```

## Step 4: Set Docker Secrets in .env

```bash
# In /opt/immogestion/services/api-backend/.env.production:
# These are also read by docker-compose.yml for the postgres container
DB_USER=postgres
DB_PASSWORD=<your-generated-password>
```

## Step 5: Build and Start

```bash
cd /opt/immogestion/services/api-backend

# Build and start all services (postgres + api)
docker compose up -d --build

# Verify:
docker compose ps
docker compose logs -f api    # Watch API logs
docker compose logs -f postgres  # Watch DB logs

# Test local origin health (container-only):
curl http://localhost:3000/health

# Test public demo surfaces (Cloudflare + DNS + app boundary):
curl https://api.immogestion.app/api/health
curl https://immogestion.app/
curl https://app.immogestion.app/
```

## Step 6: Run Migrations

```bash
# The API container auto-runs migrations via docker-entrypoint-initdb.d
# But if you need to run them manually:
docker compose exec api node -r dotenv/config scripts/migrate.js

# Seed initial data (optional):
docker compose exec api node -r dotenv/config scripts/seed.js
```

## Step 7: Cloudflare Tunnel Setup

### In Cloudflare Dashboard:
1. Go to Zero Trust -> Networks -> Tunnels
2. Create a new tunnel, name it "immogestion-api"
3. Copy the tunnel token
4. Add it to `.env.production` as `CLOUDFLARE_TUNNEL_TOKEN=...` (do not leave it commented out)

### Configure Tunnel Route:
- Public hostname: `api.immogestion.app`
- Service: `http://api:3000` (uses Docker network)
- Path: leave empty (all paths)
- Public hostnames for the Flutter web surface must also be configured in Cloudflare so:
  - `immogestion.app` serves the public landing page
  - `app.immogestion.app` serves the login wall and authenticated app shell

### In docker-compose.yml, keep the tunnel service enabled and make it depend only on the API:
```yaml
  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: immogestion-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN:?CLOUDFLARE_TUNNEL_TOKEN is required}
    networks:
      - internal
    depends_on:
      - api
```

### Restart:
```bash
docker compose up -d
```

## Step 7b: Register webhook callback URLs

These runtime hooks are required for the message + visit workflows to function end-to-end.

### Meta / Facebook Messenger
- Callback URL: `https://api.immogestion.app/api/webhooks/facebook`
- Verify token: `FB_VERIFY_TOKEN`
- Subscribe the app to the Messenger and Lead Ads events used by the backend (`messages`, `messaging_postbacks`, `messaging_optins`, `leadgen`)
- Ownership lives in `src/controllers/facebook-webhook.controller.js` for webhook ingress and `src/services/messenger-bot.service.js` for conversation logic
- Messenger remains direct Meta only; do not introduce a transport abstraction between the webhook and the bot service
- Messenger replies must respect Meta's 24-hour messaging window; follow-up outside that window should move to SMS or another approved channel

### Twilio SMS
- Incoming message webhook: `https://api.immogestion.app/api/webhooks/sms/incoming`
- Delivery status webhook: `https://api.immogestion.app/api/webhooks/sms/status`
- Outbound confirmation links use `PUBLIC_URL` / `PAPERCLIP_PUBLIC_URL`, so keep those pointing at the public API host
- Ownership lives in `src/services/twilio.service.js` and `src/controllers/sms-webhook.controller.js`
- Twilio stays SMS-only for confirmations, reminders, and delivery callbacks; do not route Messenger traffic through the SMS stack

### Runtime assumption
- The API process is the scheduler/worker for visit reminders, queue processing, and weekly digest jobs.
- Run a single always-on API instance unless the cron tasks are refactored into a separate leader-elected worker.

## Step 8: DNS Configuration

In Cloudflare DNS for immogestion.app:
- CNAME `api.immogestion.app` -> tunnel UUID.cfargotunnel.com (auto-configured by tunnel)
- The tunnel handles DNS automatically when created via dashboard

## Step 9: Verify Everything

```bash
# Health check from VPS:
curl http://localhost:3000/health

# Public verification (browser-visible demo contract):
curl https://api.immogestion.app/api/health
curl https://immogestion.app/
curl https://app.immogestion.app/

# Check all containers:
docker compose ps

# Check logs:
docker compose logs --tail=50
```

HTTP 200 from the origin or tunnel is not enough for demo readiness; confirm the public landing page and app login wall in a real browser before calling the deployment done.

## Step 10: SSL / Security

- SSL is handled automatically by Cloudflare Tunnel (no need for certbot)
- Cloudflare proxy mode provides DDoS protection
- Consider enabling additional Cloudflare security rules:
  - Rate limiting on API endpoints
  - Bot protection
  - WAF rules

## Troubleshooting: Cloudflare 1033 / tunnel down

If `https://api.immogestion.app/health` or `https://api.immogestion.app/api/health` returns a Cloudflare 1033 page, the public hostname is reachable but the tunnel has no active origin connection.

Quick checks on the VPS:

```bash
cd /opt/immogestion/services/api-backend

docker compose ps

docker compose logs --tail=100 tunnel

docker compose logs --tail=100 api

curl http://localhost:3000/health
curl http://localhost:3000/api/health
```

What to verify:
- `api` is healthy on `http://api:3000` inside the Docker network
- `tunnel` is running and connected with a valid `CLOUDFLARE_TUNNEL_TOKEN`
- `api.immogestion.app` CNAME still points to the tunnel UUID
- no firewall or VPS access issue is preventing the tunnel container from reaching Cloudflare

If SSH/VPS access is unavailable, this cannot be repaired from the sandbox; restore host access first, ensure `CLOUDFLARE_TUNNEL_TOKEN` is present in `.env.production`, and then restart the tunnel container.

## Maintenance

```bash
# View logs:
docker compose logs -f

# Restart a service:
docker compose restart api

# Update to latest code:
cd /opt/immogestion
git pull
cd services/api-backend
docker compose up -d --build

# Full reset (destroys data!):
docker compose down -v
```

## Automated Backups

Backups run automatically every day at 2:00 AM via a dedicated cron container.

### How it works
- The `backup` container runs `scripts/backup.sh` on a daily cron schedule
- Backups are gzip-compressed SQL dumps stored in the `backups` Docker volume at `/backups/`
- Filenames are date-stamped: `immogestion_YYYYMMDD_HHMMSS.sql.gz`
- Backups older than 30 days are automatically deleted
- Each backup is integrity-checked (gzip verification) before being kept

### Manual backup
```bash
docker compose exec backup /scripts/backup.sh
```

### List backups
```bash
docker compose exec backup ls -lh /backups/*.sql.gz
```

### Restore from a backup
```bash
# 1. List available backups and pick one
docker compose exec backup ls -lh /backups/*.sql.gz

# 2. Restore (replace the filename with your chosen backup)
docker compose exec postgres \
  psql -U postgres -d immogestion \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

docker compose exec backup \
  sh -c "gunzip -c /backups/immogestion_YYYYMMDD_HHMMSS.sql.gz | \
    psql -h postgres -U postgres -d immogestion"

# 3. Restart the API to pick up restored data
docker compose restart api

# 4. Verify
curl http://localhost:3000/api/health
```

### Backup retention
- Default: 30 days (configurable via `BACKUP_RETENTION_DAYS` env var in docker-compose.yml)
- Cron log: `docker compose exec backup cat /backups/cron.log`

## Health Monitoring

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Server-level health check (used by Docker healthcheck) |
| `GET /api/health` | API health with database connectivity status and latency |

### /api/health response (healthy)
```json
{
  "status": "healthy",
  "timestamp": "2026-04-14T19:00:00.000Z",
  "version": "1.0.0",
  "uptime": 86400,
  "database": { "status": "connected", "latencyMs": 3 }
}
```

### /api/health response (unhealthy)
```json
{
  "status": "unhealthy",
  "timestamp": "2026-04-14T19:00:00.000Z",
  "version": "1.0.0",
  "uptime": 86400,
  "database": { "status": "disconnected", "error": "connection refused" }
}
```
Returns HTTP 503 when the database is unreachable.

### Docker health checks
- **PostgreSQL**: `pg_isready` every 10s (5 retries)
- **API**: `wget /health` every 30s (3 retries, 15s start period)
- **Backup**: runs on cron, no continuous health check needed

### Simple monitoring cron (optional)
Add to the VPS crontab to ping the health endpoint and alert on failure:
```bash
# crontab -e
*/5 * * * * curl -sf http://localhost:3000/api/health > /dev/null || echo "$(date) API unhealthy" >> /var/log/immogestion-monitor.log
```

## Troubleshooting

| Issue | Check |
|-------|-------|
| API won't start | `docker compose logs api` |
| DB connection failed | Check DATABASE_URL in .env.production, verify postgres is healthy |
| Tunnel not connecting | Check CLOUDFLARE_TUNNEL_TOKEN, verify tunnel exists in Cloudflare dashboard |
| Health check failing | `curl http://localhost:3000/health` from VPS |
| Port already in use | `ss -tlnp | grep -E '3000|5432'` |
| Backups not running | `docker compose logs backup`, check cron log: `docker compose exec backup cat /backups/cron.log` |
| Restore failed | Verify backup integrity: `docker compose exec backup sh -c 'gzip -t /backups/YOUR_BACKUP.sql.gz'` |

## Flutter Web App

The Flutter app can be served as a web app via Docker alongside the API.

### Build and Deploy

```bash
cd /opt/immogestion/services/api-backend

# Build Flutter web (builds from monorepo root using services/flutter-web/Dockerfile)
docker compose up -d --build flutter-web

# Verify:
curl -s http://localhost:8080/ | head -5
docker compose logs -f flutter-web
```

The Flutter web app is available at `http://localhost:8080` on the VPS.

### Public Demo Entry Point

The intended public demo entry point is `https://immogestion.app`.
`https://app.immogestion.app` is the authenticated app surface and should show a login wall before app content.

### Cloudflare Tunnel Route:

Configure all public hostnames in the Cloudflare Tunnel dashboard:
- Public hostname: `immogestion.app`
  - Service: `http://flutter-web:80` (public landing)
- Public hostname: `app.immogestion.app`
  - Service: `http://flutter-web:80` (authenticated app surface)
- Public hostname: `api.immogestion.app`
  - Service: `http://api:3000` (uses Docker network)

Note: the tunnel service is already defined in `docker-compose.yml` and depends only on the API service.

### Local Development Builds

Use the build script from the project root:

```bash
# Debug APK (no signing required)
./scripts/build-release.sh --apk

# Web build
./scripts/build-release.sh --web

# Both
./scripts/build-release.sh --all

# Skip tests/analysis
./scripts/build-release.sh --apk --skip-tests
```

Builds are output to `build/release/`.

## Android Signing (for release APK)

To build a signed release APK, you need an Android keystore.

### Generate a Keystore (first time)

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Answer the prompts and store the password securely.

### Build Signed APK

```bash
export KEYSTORE_PATH=android/app/upload-keystore.jks
export KEYSTORE_PASSWORD=your-keystore-password
export KEY_ALIAS=upload
export KEY_PASSWORD=your-key-password

./scripts/build-release.sh --apk
```

### CI/CD Pipeline

GitHub Actions automatically runs on pushes to `main` and on pull requests:
- `flutter analyze` — static analysis
- `flutter test` — unit and widget tests
- APK debug build — uploaded as artifact (7-day retention)
- Web release build — uploaded as artifact (7-day retention)

See `.github/workflows/flutter-ci.yml` for full configuration.

## Architecture

```
Internet -> Cloudflare Edge -> Tunnel -> api container (port 3000) -> postgres (port 5432)
                                        |
                                       flutter-web container (port 8080)
                                        |
                                   uploads volume
                                   logs volume
                                   backups volume (daily cron backup at 2 AM)
```

All ports are bound to 127.0.0.1 only on the VPS. No ports are publicly exposed. Cloudflare Tunnel provides the public entry point.
