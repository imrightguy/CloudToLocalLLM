# ImmoGestion Backend - VPS Deployment Guide

Target: Hostinger VPS (31.97.140.7), Ubuntu 24.04, Docker with postgres.

## Prerequisites

1. SSH access to the VPS (ask Simon for credentials)
2. A Cloudflare account with the domain configured
3. GitHub repo access (already at https://github.com/imrightguy/ImmoGestion.git)

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

# Test health:
curl http://localhost:3000/health
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
4. Add it to .env.production: CLOUDFLARE_TUNNEL_TOKEN=<token>

### Configure Tunnel Route:
- Public hostname: `api.immogestion.ca`
- Service: `http://api:3000` (uses Docker network)
- Path: leave empty (all paths)

### In docker-compose.yml, uncomment the tunnel service:
```yaml
  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: immogestion-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - internal
    depends_on:
      - api
```

### Restart:
```bash
docker compose up -d
```

## Step 8: DNS Configuration

In Cloudflare DNS for immogestion.ca:
- CNAME `api.immogestion.ca` -> tunnel UUID.cfargotunnel.com (auto-configured by tunnel)
- The tunnel handles DNS automatically when created via dashboard

## Step 9: Verify Everything

```bash
# Health check from VPS:
curl http://localhost:3000/health

# Health check via public URL (after tunnel):
curl https://api.immogestion.ca/health

# Check all containers:
docker compose ps

# Check logs:
docker compose logs --tail=50
```

## Step 10: SSL / Security

- SSL is handled automatically by Cloudflare Tunnel (no need for certbot)
- Cloudflare proxy mode provides DDoS protection
- Consider enabling additional Cloudflare security rules:
  - Rate limiting on API endpoints
  - Bot protection
  - WAF rules

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

## Architecture

```
Internet -> Cloudflare Edge -> Tunnel -> api container (port 3000) -> postgres (port 5432)
                                        |
                                   uploads volume
                                   logs volume
                                   backups volume (daily cron backup at 2 AM)
```

All ports are bound to 127.0.0.1 only on the VPS. No ports are publicly exposed. Cloudflare Tunnel provides the public entry point.
