#!/usr/bin/env bash
# ── ImmoGestion Backend — One-Shot VPS Deployment ─────────────────────────
# Run this script ON the VPS (31.97.140.7) as root.
# Usage:  bash deploy-vps.sh [--skip-ssh] [--migrate-existing]
#
# --skip-ssh         Skip SSH key setup (if you already have key auth)
# --migrate-existing Migrate data from existing immogestion-postgres container
# ──────────────────────────────────────────────────────────────────────────
set -euo pipefail

VPS_PATH="/opt/immogestion"
API_DIR="$VPS_PATH/services/api-backend"
SKIP_SSH=false
MIGRATE_EXISTING=false

for arg in "$@"; do
  case "$arg" in
    --skip-ssh)         SKIP_SSH=true ;;
    --migrate-existing) MIGRATE_EXISTING=true ;;
    -h|--help)
      head -12 "$0" | grep '^#' | sed 's/^# //' | sed 's/^# //'
      exit 0 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 0. Prerequisites Check ──────────────────────────────────────────────
info "Checking prerequisites..."
command -v docker >/dev/null 2>&1  || error "Docker not installed. Run: curl -fsSL https://get.docker.com | sh"
docker compose version >/dev/null 2>&1 || error "Docker Compose not available"
command -v git >/dev/null 2>&1      || error "Git not installed"

info "Prerequisites OK"

# ── 1. SSH Key Setup (optional) ──────────────────────────────────────────
if [[ "$SKIP_SSH" == true ]]; then
  warn "Skipping SSH key setup (--skip-ssh)"
else
  info "Setting up SSH key for deployment access..."
  SSH_KEY="$HOME/.ssh/immogestion_deploy"
  if [[ -f "$SSH_KEY" ]]; then
    info "SSH key already exists at $SSH_KEY"
  else
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "immogestion-deploy" -f "$SSH_KEY" -N "" -q
    info "Generated new SSH key at $SSH_KEY"
  fi

  # Ensure authorized_keys includes the deploy key
  PUB_KEY=$(cat "$SSH_KEY.pub")
  AUTH_FILE="$HOME/.ssh/authorized_keys"
  touch "$AUTH_FILE"
  if grep -qF "$PUB_KEY" "$AUTH_FILE" 2>/dev/null; then
    info "Deploy key already in authorized_keys"
  else
    echo "$PUB_KEY" >> "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    info "Added deploy key to authorized_keys"
  fi
fi

# ── 2. System Updates ────────────────────────────────────────────────────
info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ── 3. Migrate Existing PostgreSQL Data (if requested) ────────────────────
if [[ "$MIGRATE_EXISTING" == true ]]; then
  if docker ps --format '{{.Names}}' | grep -q 'immogestion-postgres'; then
    info "Found existing immogestion-postgres container. Backing up..."
    EXISTING_BACKUP="/tmp/immogestion-pg-backup-$(date +%Y%m%d%H%M%S).sql"
    docker exec immogestion-postgres pg_dumpall -U postgres > "$EXISTING_BACKUP"
    info "Backup saved to $EXISTING_BACKUP ($(du -h "$EXISTING_BACKUP" | cut -f1))"
  else
    warn "No existing immogestion-postgres container found. Skipping migration."
  fi
else
  warn "If you have an existing immogestion-postgres container, re-run with --migrate-existing"
fi

# ── 4. Stop Old Containers (clean slate) ──────────────────────────────────
info "Cleaning up old containers..."
for c in immogestion-postgres immogestion-api immogestion-db immogestion-tunnel; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    warn "Stopping and removing old container: $c"
    docker stop "$c" 2>/dev/null || true
    docker rm "$c" 2>/dev/null || true
  fi
done

# ── 5. Clone / Update Repo ───────────────────────────────────────────────
info "Setting up application at $VPS_PATH..."
if [[ -d "$VPS_PATH/.git" ]]; then
  info "Repo already exists. Pulling latest..."
  cd "$VPS_PATH"
  git pull
else
  info "Cloning repository..."
  mkdir -p "$(dirname "$VPS_PATH")"
  if [[ -d "$VPS_PATH" ]]; then
    # Directory exists but no git — move contents out
    BACKUP_DIR="${VPS_PATH}_backup_$(date +%Y%m%d%H%M%S)"
    mv "$VPS_PATH" "$BACKUP_DIR"
    warn "Moved existing $VPS_PATH to $BACKUP_DIR"
  fi
  git clone https://github.com/imrightguy/ImmoGestion.git "$VPS_PATH"
fi

cd "$API_DIR"

# ── 6. Generate Secrets ──────────────────────────────────────────────────
info "Generating production secrets..."
if [[ -f .env.production ]]; then
  warn ".env.production already exists. Preserving existing values."
  # Source existing values
  set -a; source .env.production; set +a
fi

generate_secret() {
  openssl rand -base64 48 | tr -d '\n'
}

# Only generate if not already set
DB_PASSWORD="${DB_PASSWORD:-$(generate_secret)}"
JWT_SECRET="${JWT_SECRET:-$(generate_secret)}"
JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET:-$(generate_secret)}"

info "Writing .env.production..."
cat > .env.production <<EOF
# ── ImmoGestion Production Environment ────────────────────────────────
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# ──────────────────────────────────────────────────────────────────────

# ── Server ────────────────────────────────────────────────────────────
NODE_ENV=production
PORT=3000
LOG_LEVEL=info

# ── Database ──────────────────────────────────────────────────────────
DB_USER=postgres
DB_PASSWORD=***
DATABASE_URL=postgres://postgres:***@postgres:5432/immogestion
# DB_SSL=true  (enable if using an external database that requires SSL)

# ── JWT ───────────────────────────────────────────────────────────────
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
JWT_EXPIRES_IN=24h

# ── App URLs ──────────────────────────────────────────────────────────
APP_URL=https://api.immogestion.ca
PUBLIC_URL=https://api.immogestion.ca
ALLOWED_ORIGINS=https://immogestion.ca,https://app.immogestion.ca,https://api.immogestion.ca

# ── Twilio (fill in with real values) ─────────────────────────────────
TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID:-}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN:-}
TWILIO_PHONE_NUMBER=${TWILIO_PHONE_NUMBER:-}
SIMON_PHONE=${SIMON_PHONE:-}

# ── Email (SMTP — fill in when ready) ─────────────────────────────────
SMTP_HOST=${SMTP_HOST:-}
SMTP_PORT=587
SMTP_USER=${SMTP_USER:-}
SMTP_PASS=${SMTP_PASS:-}
SMTP_FROM=${SMTP_FROM:-noreply@immogestion.ca}

# ── Paperclip Integration ────────────────────────────────────────────
PAPERCLIP_PUBLIC_URL=${PAPERCLIP_PUBLIC_URL:-https://paperclip.immogestion.ca}

# ── Security ─────────────────────────────────────────────────────────
BCRYPT_ROUNDS=12

# ── Cloudflare Tunnel (uncomment and fill in after tunnel setup) ──────
# CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN:-}
EOF

chmod 600 .env.production
info ".env.production created (secrets generated)"

# ── 7. Export DB_PASSWORD for docker-compose ──────────────────────────────
export DB_PASSWORD

# ── 8. Build and Start ───────────────────────────────────────────────────
info "Building and starting Docker containers..."
docker compose up -d --build

# ── 9. Wait for Health Check ─────────────────────────────────────────────
info "Waiting for API to become healthy..."
MAX_WAIT=120
ELAPSED=0
while [[ $ELAPSED -lt $MAX_WAIT ]]; do
  if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    HEALTH=$(curl -s http://localhost:3000/health)
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
    info "API is healthy!"
    break
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  info "Waiting... (${ELAPSED}s / ${MAX_WAIT}s)"
done

if [[ $ELAPSED -ge $MAX_WAIT ]]; then
  error "API did not become healthy within ${MAX_WAIT}s. Check logs: cd $API_DIR && docker compose logs api"
fi

# ── 10. Restore Migration Data (if applicable) ────────────────────────────
if [[ "$MIGRATE_EXISTING" == true ]] && [[ -n "${EXISTING_BACKUP:-}" ]] && [[ -f "$EXISTING_BACKUP" ]]; then
  info "Restoring existing database data..."
  docker compose exec -T postgres psql -U postgres -d immogestion < "$EXISTING_BACKUP" || {
    warn "Migration restore had warnings. Check the data manually."
  }
  info "Database restore complete. Backup at: $EXISTING_BACKUP"
fi

# ── 11. Summary ──────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  ImmoGestion Backend deployed successfully!${NC}"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Container status:"
docker compose ps
echo ""
echo "  Health check:"
curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null
echo ""
echo "  Next steps:"
echo "    1. Fill in Twilio credentials in .env.production (if needed now):"
echo "       nano $API_DIR/.env.production"
echo "       docker compose restart api"
echo ""
echo "    2. Set up Cloudflare Tunnel (see IMM-49):"
echo "       - Create tunnel at Cloudflare Zero Trust dashboard"
echo "       - Add CLOUDFLARE_TUNNEL_TOKEN to .env.production"
echo "       - Uncomment tunnel service in docker-compose.yml"
echo "       - docker compose up -d"
echo ""
echo "    3. Quick commands:"
echo "       cd $API_DIR"
echo "       make logs:api       # View API logs"
echo "       make deploy:health  # Health check"
echo "       make deploy         # Update to latest code"
echo ""
echo "  IMPORTANT: Save these secrets somewhere secure!"
echo "    DB_PASSWORD, JWT_SECRET, JWT_REFRESH_SECRET"
echo "    (stored in $API_DIR/.env.production)"
echo ""
