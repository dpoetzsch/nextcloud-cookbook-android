#!/usr/bin/env bash
# Start the throwaway Nextcloud, install the Cookbook app, seed sample recipes (first run only).
#   ./devenv/nextcloud/up.sh          start (idempotent)
#   ./devenv/nextcloud/up.sh reset    wipe all data and start fresh
set -euo pipefail
cd "$(dirname "$0")"

dk() { if id -nG | grep -qw docker; then "$@"; else sg docker -c "$(printf '%q ' "$@")"; fi; }

[ "${1:-}" = "reset" ] && dk docker compose down -v

dk docker compose up -d
echo "Waiting for Nextcloud to finish installing..."
until curl -fs http://localhost:8080/status.php | grep -q '"installed":true'; do sleep 3; done

occ() { dk docker exec -u www-data nextcloud-dev php occ "$@"; }
if ! occ app:list --enabled | grep -q 'cookbook:'; then
  occ app:install cookbook || occ app:enable cookbook
fi

count="$(curl -fs -u admin:admin http://localhost:8080/index.php/apps/cookbook/api/v1/recipes | grep -o '"recipe_id"' | wc -l || echo 0)"
if [ "$count" -eq 0 ]; then ./seed-recipes.sh; else echo "$count recipes already present."; fi

echo "Nextcloud ready: http://localhost:8080 (VM) / http://10.0.2.2:8080 (emulator) — admin/admin"
