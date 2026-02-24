#!/usr/bin/env bash
set -e

echo "Waiting for postgres..."
until nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"; do
  sleep 1
done
echo "Postgres is up."

echo "Running migrations..."
python manage.py migrate --noinput

# Optional but common (especially if you serve static via nginx)
if [ "${DJANGO_COLLECTSTATIC:-1}" = "1" ]; then
  echo "Collecting static..."
  python manage.py collectstatic --noinput
fi

# Optional: create cache table if you use DB cache
# python manage.py createcachetable || true

echo "Starting server..."
exec "$@"