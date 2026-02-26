#!/bin/bash
set -eu

echo "==> CloudToLocalLLM Cloudron Start Script <=="

# Map Cloudron environment variables to the app's expected env variables
export DATABASE_URL=${CLOUDRON_POSTGRESQL_URL}
export REDIS_URL=${CLOUDRON_REDIS_URL}

# App initialization like DB migrations
echo "==> Running database migrations..."
cd /app/code/api-backend
npm run db:migrate || echo "Notice: Database migration check finished or bypassed."

echo "==> Starting supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
