# ImmoGestion Production Deployment Checklist

## Pre-Deployment

- [ ] All code merged to `main` and CI passes (Flutter analyze + tests + build)
- [ ] `.env.production` created on VPS (copy from `.env.production.template`, fill all values)
- [ ] `JWT_SECRET` is random, at least 32 characters (generate: `openssl rand -hex 32`)
- [ ] `JWT_REFRESH_SECRET` is random, at least 32 characters
- [ ] `DB_PASSWORD` is strong and unique
- [ ] `ALLOWED_ORIGINS` set to production domains only (no `*` wildcard)
- [ ] `NODE_ENV=production` set in docker-compose environment
- [ ] Swagger docs endpoint disabled (only served in non-production)
- [ ] `.env.production` is NOT committed to git (verified in `.gitignore`)
- [ ] `FB_VERIFY_TOKEN` and `FB_PAGE_ACCESS_TOKEN` are set if Messenger / Lead Ads are enabled
- [ ] Messenger outbound follow-ups stay within Meta's 24-hour messaging window; after that, use SMS or another approved channel
- [ ] `PUBLIC_URL` or `PAPERCLIP_PUBLIC_URL` points to the public API base used in confirmation SMS links

## Security Verification

- [ ] Cloudflare SSL/TLS mode set to "Full" (or "Full (Strict)")
- [ ] Cloudflare Tunnel token configured and tunnel service running in docker-compose
- [ ] GitHub Actions has a `GHCR_TOKEN` secret with `read:packages` so the VPS can authenticate before pulling private images
- [ ] Cloudflare DNS routes exist for `immogestion.app`, `app.immogestion.app`, and `api.immogestion.app`
- [ ] Public hostnames in the Cloudflare Tunnel dashboard point `immogestion.app` to the Flutter web container and `app.immogestion.app` to the authenticated app surface
- [ ] Facebook webhook callback configured: `https://api.immogestion.app/api/webhooks/facebook`
- [ ] Twilio callbacks configured: `https://api.immogestion.app/api/webhooks/sms/incoming` and `https://api.immogestion.app/api/webhooks/sms/status`
- [ ] Messenger and Twilio remain separate transport boundaries; no generic channel abstraction routes traffic between them
- [ ] Rate limiting active: 100 req/15min global, 10 req/15min on `/api/auth`
- [ ] Helmet.js security headers enabled (CSP, HSTS, X-Frame-Options, Referrer-Policy)
- [ ] Nginx security headers: `server_tokens off`, X-Frame-Options, X-Content-Type-Options, Permissions-Policy
- [ ] CORS restricted to `https://immogestion.app,https://app.immogestion.app,https://api.immogestion.app`
- [ ] No ports exposed publicly (all bound to `127.0.0.1`, tunnel handles external access)
- [ ] Non-root container user (`appuser`) runs the API process
- [ ] Docker image scanned: `docker scout cves immogestion-api` — no critical CVEs
- [ ] API fails fast on startup if required env vars are missing or JWT_SECRET < 32 chars

## Observability Verification

- [ ] Centralized logs are retained and searchable for the core workflow events: inbound message, lead creation, visit scheduling, SMS send, confirmation, and outcome update
- [ ] Dashboard/analytics views are available for message-to-visit conversion, visit completion, and no-show rates
- [ ] Alerts exist for webhook failures, SMS delivery failures, scheduler/job crashes, and elevated 5xx rates on workflow routes

## Docker & Infrastructure

- [ ] Docker log rotation configured (10MB max, 3 files per container)
- [ ] API container memory limit set (512M)
- [ ] All containers have health checks configured
- [ ] PostgreSQL health check verified (`pg_isready`)
- [ ] API health check verified (`/health` endpoint)
- [ ] Flutter web health check verified (HTTP 200 from nginx)
- [ ] Backup cron container running (daily at 2:00 AM)
- [ ] Backup retention set to 30 days
- [ ] Database port (5432) only on localhost
- [ ] API port (3000) only on localhost
- [ ] API runs as a single always-on instance so in-process schedulers do not duplicate work

## Deployment

```bash
# On VPS
cd /opt/immogestion/services/api-backend
git pull origin main
docker compose up -d --build
docker compose ps          # verify all containers healthy
docker compose logs -f api # watch for startup errors
```

## Smoke Tests

Verify these endpoints return expected responses after deployment.

Note: HTTP 200 alone does not prove public demo readiness. Confirm the landing page and login wall in a real browser before declaring the deployment usable.

| Endpoint | Expected |
|---|---|
| `GET https://api.immogestion.app/health` | `{ "status": "healthy", ... }` |
| `GET https://api.immogestion.app/api/health` | `{ "status": "healthy", "database": { "status": "connected" } }` |
| `GET https://immogestion.app/` | Public landing page renders |
| `GET https://app.immogestion.app/` | Login wall renders for signed-out visitors; authenticated users can reach the app shell |
| `GET https://api.immogestion.app/api/docs` | 404 (Swagger disabled in production) |

The `immogestion.app` and `app.immogestion.app` checks must be done in a real browser when verifying demo readiness; the table is a minimum connectivity check, not the full contract.

## Backup Verification

- [ ] Verify backup file exists: `docker exec immogestion-backup ls -la /backups/`
- [ ] Check backup integrity: `docker exec immogestion-backup gzip -t /backups/<latest>.sql.gz`
- [ ] Test restore procedure:
  ```bash
  # Create a test database
  docker exec immogestion-db psql -U postgres -c "CREATE DATABASE immogestion_restore_test;"

  # Restore latest backup
  docker exec immogestion-backup sh -c \
    "gunzip -c /backups/<latest>.sql.gz | psql -h postgres -U postgres -d immogestion_restore_test"

  # Verify tables exist
  docker exec immogestion-db psql -U postgres -d immogestion_restore_test -c "\dt"

  # Clean up test database
  docker exec immogestion-db psql -U postgres -c "DROP DATABASE immogestion_restore_test;"
  ```

## Rollback Procedure

```bash
# 1. Identify the previous working commit
cd /opt/immogestion
git log --oneline -5

# 2. Rollback to previous version
git checkout <previous-commit>
cd services/api-backend
docker compose up -d --build

# 3. Verify health
curl -s http://localhost:3000/health | python3 -m json.tool

# 4. If rollback fails, restore database from backup (see Backup Verification above)

# 5. Once stable, switch main back
cd /opt/immogestion
git checkout main
```

## Monitoring

Check these regularly after deployment:

- `docker compose ps` — all services should show "healthy"
- `docker compose logs --tail=100 api` — no unhandled errors
- `docker compose logs --tail=50 backup` — backups completing successfully
- Cloudflare dashboard — SSL status, tunnel connection, traffic analytics
- VPS resources: `df -h`, `free -m`, `docker stats` — ensure no resource exhaustion
