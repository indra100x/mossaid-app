#!/bin/sh
set -e

if [ -z "$APP_KEY" ]; then
  echo "ERROR: APP_KEY is not set. Generate one and export it:"
  echo "  cd api && php artisan key:generate --show"
  exit 1
fi

# Bake config with the runtime env (caches are rebuilt on every start,
# so env changes apply after a container restart, not a rebuild).
php artisan config:cache
php artisan route:cache
php artisan view:cache

if [ "${DB_MIGRATE:-true}" = "true" ]; then
  php artisan migrate --force
fi

php-fpm -D
exec nginx -g 'daemon off;'
