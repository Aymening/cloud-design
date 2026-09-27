#!/bin/bash
# Builds and starts the full local stack, waits for inventory-app and
# billing-app to report healthy, then tears everything down.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env not found - copy .env.example to .env first" >&2
  exit 1
fi

cleanup() {
  echo "Tearing down..."
  docker compose down --volumes
}
trap cleanup EXIT

echo "Building and starting services..."
docker compose up -d --build

echo "Waiting for inventory-app and billing-app to become healthy..."
for i in $(seq 1 30); do
  inventory_ok=$(curl -sf http://localhost:8081/health >/dev/null && echo 1 || echo 0)
  billing_ok=$(curl -sf http://localhost:8082/health >/dev/null && echo 1 || echo 0)

  if [ "$inventory_ok" = "1" ] && [ "$billing_ok" = "1" ]; then
    echo "Both services are healthy."
    curl -s http://localhost:8081/health
    echo
    curl -s http://localhost:8082/health
    echo
    exit 0
  fi

  sleep 2
done

echo "Services did not become healthy in time." >&2
docker compose ps
docker compose logs --tail=50
exit 1
