#!/usr/bin/env bash
# Full cleanup and start of test stack (Vault Raft + LDAP).
# Compose is at repo root; all volume mounts are under test-env-resources/
# Run from repo root: ./test-env-resources/start-test-env.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Remove legacy root-level vault-data/vault-logs (test env uses test-env-resources/)
for dir in vault-data vault-logs; do
  if [ -d "$REPO_ROOT/$dir" ]; then
    echo "Removing legacy $dir from repo root..."
    rm -rf "$REPO_ROOT/$dir"
  fi
done

echo "Stopping and removing containers (including orphans)..."
docker compose down --remove-orphans 2>/dev/null || docker-compose down --remove-orphans 2>/dev/null || true

echo "Force-removing any leftover test containers..."
for c in vault-1 vault-2 vault-3 vault-1-init vault-2-init vault-3-init ldap-test ldap-init; do
  docker rm -f "$c" 2>/dev/null || true
done

# Ensure Raft data dirs exist and are writable by Vault (UID 100) in container.
# On macOS bind mounts, chown inside the container often fails; chmod makes dirs writable.
mkdir -p test-env-resources/raft-data/vault-1 test-env-resources/raft-data/vault-2 test-env-resources/raft-data/vault-3
chmod -R 777 test-env-resources/raft-data/vault-1 test-env-resources/raft-data/vault-2 test-env-resources/raft-data/vault-3

echo "Starting stack..."
docker compose up -d 2>/dev/null || docker-compose up -d

echo "Waiting for vault-1 to respond..."
set +e
for i in $(seq 1 30); do
  docker exec vault-1 vault status -address=http://127.0.0.1:8300 2>/dev/null
  r=$?
  # 0 = initialized, 2 = uninitialized (API is up)
  if [ "$r" -eq 0 ] || [ "$r" -eq 2 ]; then
    set -e
    echo "Vault is up. UI: http://localhost:18200/ui"
    [ "$r" -eq 2 ] && echo "Run from repo root: ./run-playbook.sh init"
    exit 0
  fi
  sleep 2
done
set -e
echo "Vault did not become ready. Check: docker logs vault-1"
exit 1
