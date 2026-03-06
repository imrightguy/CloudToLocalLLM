#!/bin/bash
set -e

echo "==> CloudToLocalLLM Docker Swarm Start Script <=="

# Map environment variables for Docker Swarm deployment
# These can be set as Docker Swarm service config or environment variables
export DATABASE_URL=${DATABASE_URL:-}
export REDIS_URL=${REDIS_URL:-}

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
