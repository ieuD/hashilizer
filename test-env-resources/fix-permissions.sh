#!/bin/bash
# Fix Vault permissions on test env (bind mounts under test-env-resources/raft-data).
# Run from repo root: ./test-env-resources/fix-permissions.sh
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Fixing Vault permissions issue..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Fix permissions on bind-mounted Raft dirs under test-env-resources
for d in test-env-resources/raft-data/vault-1 test-env-resources/raft-data/vault-2 test-env-resources/raft-data/vault-3; do
  if [ -d "$d" ]; then
    echo "Fixing $d..."
    sudo chown -R 100:1000 "$d" 2>/dev/null || chown -R 100:1000 "$d" 2>/dev/null || true
  fi
done

echo "Starting stack..."
docker compose up -d 2>/dev/null || docker-compose up -d
echo "Done. Run from repo root: ./run-playbook.sh init"
