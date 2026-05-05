#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TEST_DB_URL="postgres://postgres:postgres@127.0.0.1:55432/immogestion_test"
TEST_DB_CONTAINER="${TEST_DB_CONTAINER:-immogestion-integration-db}"
TEST_DB_PORT="${TEST_DB_PORT:-55432}"
TEST_DB_USER="${TEST_DB_USER:-postgres}"
TEST_DB_PASSWORD="${TEST_DB_PASSWORD:-postgres}"
TEST_DB_NAME="${TEST_DB_NAME:-immogestion_test}"

if [[ -z "${TEST_DATABASE_URL:-}" ]]; then
  TEST_DATABASE_URL="$DEFAULT_TEST_DB_URL"
  export TEST_DATABASE_URL

  if ! command -v docker >/dev/null 2>&1; then
    echo "TEST_DATABASE_URL is not set and docker is unavailable. Either install docker or export TEST_DATABASE_URL to a disposable PostgreSQL database." >&2
    exit 1
  fi

  if docker inspect "$TEST_DB_CONTAINER" >/dev/null 2>&1; then
    running="$(docker inspect -f '{{.State.Running}}' "$TEST_DB_CONTAINER")"
    if [[ "$running" != "true" ]]; then
      docker rm -f "$TEST_DB_CONTAINER" >/dev/null 2>&1 || true
    fi
  fi

  if ! docker inspect "$TEST_DB_CONTAINER" >/dev/null 2>&1; then
    docker run -d \
      --name "$TEST_DB_CONTAINER" \
      -e POSTGRES_DB="$TEST_DB_NAME" \
      -e POSTGRES_USER="$TEST_DB_USER" \
      -e POSTGRES_PASSWORD="$TEST_DB_PASSWORD" \
      -p "127.0.0.1:${TEST_DB_PORT}:5432" \
      postgres:16-alpine >/dev/null
  fi

  for _ in $(seq 1 30); do
    if docker exec "$TEST_DB_CONTAINER" pg_isready -U "$TEST_DB_USER" -d "$TEST_DB_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! docker exec "$TEST_DB_CONTAINER" pg_isready -U "$TEST_DB_USER" -d "$TEST_DB_NAME" >/dev/null 2>&1; then
    echo "Integration test database did not become ready: $TEST_DB_CONTAINER" >&2
    exit 1
  fi
fi

export DATABASE_URL="${DATABASE_URL:-$TEST_DATABASE_URL}"
export JWT_SECRET="${JWT_SECRET:-integration-test-jwt-secret-0123456789abcdef}"
export JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET:-integration-test-refresh-secret-0123456789abcdef}"
export JEST_INCLUDE_INTEGRATION=true
export LOG_LEVEL="${LOG_LEVEL:-silent}"

exec npx jest __tests__/integration/ --forceExit --runInBand "$@"
