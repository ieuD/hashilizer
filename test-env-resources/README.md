# Test environment resources

All volume mounts for the test stack live under this directory. The Compose file is at **repo root** (`docker-compose.yml`).

Docker-based test stack: 3-node Vault (Raft) + OpenLDAP.

## Layout

- **start-test-env.sh** – Clean start (run from repo root; creates raft-data dirs, runs `docker compose up -d`)
- **fix-permissions.sh** – Fix Raft dir permissions if Vault fails with "permission denied"
- **vault-config/** – Vault HCL configs per node (listener 8300, Raft, retry_join)
- **ldap/** – LDAP bootstrap LDIFs (OU, `sa.vault` user)
- **raft-data/** – Raft data bind-mounted by Compose (`vault-1`, `vault-2`, `vault-3`; gitignored)

## Start the stack

From repo root:

```bash
./test-env-resources/start-test-env.sh
# or
docker compose up -d
```

If Vault shows "uninitialized", from repo root run:

```bash
./run-playbook.sh init
```

## Stop / clean

From repo root:

```bash
docker compose down
```

Raft data stays under `test-env-resources/raft-data/` until you delete those directories.
