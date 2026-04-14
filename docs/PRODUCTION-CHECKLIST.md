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

## Security Verification

- [ ] Cloudflare SSL/TLS mode set to "Full" (or "Full (Strict)")
- [ ] Cloudflare Tunnel token configured and tunnel service uncommented in docker-compose
- [ ] Rate limiting active: 100 req/15min global, 10 req/15min on `/api/auth`
- [ ] Helmet.js security headers enabled (CSP, HSTS, X-Frame-Options, Referrer-Policy)
- [ ] Nginx security headers: `server_tokens off`, X-Frame-Options, X-Content-Type-Options, Permissions-Policy
- [ ] CORS restricted to `https://immogestion.ca,https://app.immogestion.ca,https://api.immogestion.ca`
- [ ] No ports exposed publicly (all bound to `127.0.0.1`, tunnel handles external access)
- [ ] Non-root container user (`appuser`) runs the API process
- [ ] Docker image scanned: `docker scout cves immogestion-api` — no critical CVEs
- [ ] API fails fast on startup if required env vars are missing or JWT_SECRET < 32 chars

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

Verify these endpoints return expected responses after deployment:

| Endpoint | Expected |
|---|---|
| `GET https://api.immogestion.ca/health` | `{ "status": "healthy", ... }` |
| `GET https://api.immogestion.ca/api/health` | `{ "status": "healthy", "database": { "status": "connected" } }` |
| `GET https://immogestion.ca/` | Flutter web app loads |
| `GET https://api.immogestion.ca/api/docs` | 404 (Swagger disabled in production) |

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
