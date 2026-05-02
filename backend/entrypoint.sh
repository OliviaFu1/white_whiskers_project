#!/usr/bin/env bash
set -e

# Support both Railway's PG* vars and local DB_* vars
PG_HOST="${PGHOST:-${DB_HOST:-localhost}}"
PG_PORT="${PGPORT:-${DB_PORT:-5432}}"

if [ -n "$PG_HOST" ]; then
  echo "Waiting for postgres at $PG_HOST:$PG_PORT..."
  until nc -z "$PG_HOST" "$PG_PORT"; do
    sleep 1
  done
  echo "Postgres is up."
fi

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting server..."
exec "$@"
