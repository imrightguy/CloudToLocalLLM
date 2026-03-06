#!/bin/bash
set -e

echo "==> CloudToLocalLLM Docker Swarm Start Script <=="

# Map environment variables (Cloudron or direct)
# For Docker Swarm deployment, these may not be set
export DATABASE_URL=${DATABASE_URL:-${CLOUDRON_POSTGRESQL_URL:-}}
export REDIS_URL=${REDIS_URL:-${CLOUDRON_REDIS_URL:-}}

# App initialization like DB migrations
echo "==> Running database migrations..."
cd /app/code/api-backend
if [ -n "$DATABASE_URL" ]; then
    npm run db:migrate || echo "Notice: Database migration check finished or bypassed."
else
    echo "Notice: DATABASE_URL not set, skipping migrations."
fi

echo "==> Starting supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
