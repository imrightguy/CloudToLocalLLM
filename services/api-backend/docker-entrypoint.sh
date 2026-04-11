#!/bin/sh
set -e

echo "[entrypoint] Starting ImmoGestion API..."

# Wait for postgres to be ready
echo "[entrypoint] Waiting for PostgreSQL..."
until pg_isready -h "${DB_HOST:-postgres}" -p 5432 -U "${DB_USER:-postgres}" -q; do
  echo "[entrypoint] PostgreSQL not ready, retrying in 2s..."
  sleep 2
done
echo "[entrypoint] PostgreSQL is ready."

# Run SQL migrations if they haven't been applied yet
# docker-entrypoint-initdb.d only runs on first DB creation,
# so we apply migrations here for subsequent starts too.
MIGRATION_DIR="/app/migrations"
if [ -d "$MIGRATION_DIR" ] && ls "$MIGRATION_DIR"/*.sql >/dev/null 2>&1; then
  # Create a migrations tracking table if it doesn't exist
  psql "${DATABASE_URL}" -c "
    CREATE TABLE IF NOT EXISTS _applied_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT NOW()
    );
  " 2>/dev/null || true

  for migration_file in "$MIGRATION_DIR"/*.sql; do
    filename=$(basename "$migration_file")
    escaped_filename=$(printf '%s' "$filename" | sed "s/'/''/g")
    applied=$(psql "$DATABASE_URL" -tAc "SELECT 1 FROM _applied_migrations WHERE filename='$escaped_filename';" 2>/dev/null || echo "")
    if [ "$applied" != "1" ]; then
      echo "[entrypoint] Applying migration: $filename"
      psql "$DATABASE_URL" -f "$migration_file"
      psql "$DATABASE_URL" -c "INSERT INTO _applied_migrations (filename) VALUES ('$escaped_filename') ON CONFLICT DO NOTHING;"
      echo "[entrypoint] Applied: $filename"
    else
      echo "[entrypoint] Skipping (already applied): $filename"
    fi
  done
fi

echo "[entrypoint] Starting server..."
exec dumb-init -- "$@"
