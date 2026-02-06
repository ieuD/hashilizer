# HashiCorp Vault Ansible Configuration

Modular Ansible playbooks for HashiCorp Vault: initialization, unseal/seal, audit logging, and policy management. Test environment uses Docker (3-node Raft); production uses virtual machines.

## Features

- **Modular design** – Run init, unseal, seal, audit, or policies independently
- **Vault init & unseal** – Initialize, save unseal keys and root token, auto-unseal
- **Seal all nodes** – Seal active via API; optionally seal standbys by restart (Docker or systemd)
- **Audit logging** – File-based audit devices, configurable paths and options
- **Policies from folder** – Load from `policies/`: all `.hcl` files or a list of filenames
- **Security** – Root token and unseal keys are never logged (`no_log`)
- **Test env** – Docker Compose 3-node Raft + LDAP; **Production** – VM-based inventory

## Project Structure

```
├── ansible.cfg
├── site.yml
├── Makefile                        # make init, make all, make prod-all, etc.
├── docker-compose.yml              # Test: 3-node Vault Raft + LDAP
├── test-env-resources/
│   ├── start-test-env.sh           # Start test env (creates dirs, compose up)
│   ├── fix-permissions.sh          # Raft dir permissions for bind mounts
│   ├── vault-config/               # vault-1.hcl, vault-2.hcl, vault-3.hcl
│   ├── ldap/                       # LDAP bootstrap
│   └── raft-data/                  # Raft data (gitignored)
├── group_vars/                     # all.yml, test.yml, production.yml, vault_servers.yml
├── inventories/
│   ├── test                        # 3 nodes localhost:18200, 18202, 18204
│   ├── production
│   └── group_vars/
│       └── test.yml                # e.g. vault_policies_use_all: true for test
├── playbooks/
│   ├── init-only.yml
│   ├── unseal-only.yml
│   ├── seal-only.yml
│   ├── audit-only.yml
│   ├── policies-only.yml
│   └── site.yml
├── roles/
│   ├── vault-init
│   ├── vault-unseal
│   ├── vault-seal
│   ├── vault-audit
│   ├── vault-policies
│   └── vault-auth
└── policies/                       # .hcl policy files (e.g. admin.hcl)
```

## Quick Start

### 1. Start test environment (Docker)

```bash
./test-env-resources/start-test-env.sh
# or: docker compose up -d
```

Vault nodes: `localhost:18200`, `localhost:18202`, `localhost:18204`.

### 2. Initialize and unseal

```bash
make init    # Initialize (vault-1 only), save keys + root token, unseal
make unseal  # Unseal all nodes (if already initialized)
```

### 3. Configure audit and policies

```bash
make audit
make policies
```

### 4. Full run (test)

```bash
make all
```

### 5. List all commands

```bash
make        # or make help
```

## Makefile targets

| Target        | Description                          |
|---------------|--------------------------------------|
| `make init`   | Initialize Vault (vault-1), save keys + token, unseal |
| `make unseal` | Unseal all nodes (uses `~/.vault_keys`) |
| `make seal`   | Seal all nodes (active via API; standbys by restart when configured) |
| `make audit`  | Configure audit logging only         |
| `make policies` | Apply policies from `policies/`    |
| `make all`    | Full config (init, unseal, audit, policies, auth) |

**Production** (uses `inventories/production` and VM vars):

- `make prod-init`, `make prod-unseal`, `make prod-seal`, `make prod-audit`, `make prod-policies`, `make prod-all`

## Roles

### vault-init

- Checks if Vault is initialized; initializes with configurable key shares/threshold
- Saves unseal keys to `~/.vault_keys` and root token to `~/.vault_root_token`
- Unseals Vault; verifies health  
- **Variables:** `vault_key_threshold`, `vault_key_shares`, `vault_auto_unseal_on_init`, `vault_force_init`

### vault-unseal

- Reads unseal keys from file or `vault_unseal_keys`; POSTs to `/v1/sys/unseal` until unsealed
- **Variables:** `vault_unseal_keys_file`, `vault_auto_unseal`, `vault_key_threshold`

### vault-seal

- Seals the **active** node via API. Standby nodes cannot be sealed via API.
- **Seal all nodes:** set `vault_seal_standbys_by_restart: true` and `vault_seal_restart_command`:
  - **Test (Docker):** `vault_seal_restart_command: "docker restart {{ inventory_hostname }}"`
  - **Production (VMs):** `vault_seal_restart_command: "systemctl restart vault"`
- **Variables:** `vault_root_token_file`, `vault_seal_standbys_by_restart`, `vault_seal_restart_command`

### vault-audit

- Enables file-based audit devices; creates log dirs and files with correct permissions
- **Variables:** `vault_audit_devices`, `vault_audit_log_dir`, `vault_audit_force_enable`, `vault_audit_remove_existing`

### vault-policies

Policies are loaded from the **policies/** folder only (no inline content in vars).

- **Feature flag:** `vault_policies_use_all`
  - **`true`** – Include **all** `.hcl` files under `policies/` (e.g. admin, app-secrets, database-admin, devx-admin)
  - **`false`** – Use **`vault_default_policies`** as a list of filenames (e.g. `["admin.hcl"]`) and load only those
- **Variables:**
  - `vault_policies_use_all` – boolean (default `false`)
  - `vault_default_policies` – list of filenames, e.g. `["admin.hcl"]`
  - `vault_policies_source_dir` – directory for `.hcl` files (default: `{{ playbook_dir }}/../policies`)
  - `vault_policies_update_existing` – allow updating existing policies

**Test inventory:** For `-i inventories/test`, set `vault_policies_use_all: true` in **`inventories/group_vars/test.yml`** so Ansible loads it; the role then discovers and applies all `.hcl` files in `policies/`.

### vault-auth

- Enables auth methods (e.g. userpass, approle) and optional test users
- **Variables:** `vault_auth_methods`, `vault_test_users`

## Configuration

### Policies folder

Place `.hcl` policy files in `policies/`:

- **admin.hcl** – Full access (path `*`, auth, audit, policies)
- **app-secrets.hcl**, **database-admin.hcl**, **devx-admin.hcl** – Optional; applied when `vault_policies_use_all: true`

When `vault_policies_use_all: false`, only files listed in `vault_default_policies` (e.g. `["admin.hcl"]`) are applied.

### Environment-specific vars

- **group_vars/all.yml** – Defaults (e.g. `vault_policies_use_all: false`, `vault_default_policies: ["admin.hcl"]`)
- **group_vars/test.yml** – Test overrides (Docker, ports, audit to `/tmp`, etc.)
- **group_vars/production.yml** – Production (VMs, systemd, stricter settings)
- **inventories/group_vars/test.yml** – Loaded when using `-i inventories/test` (e.g. `vault_policies_use_all: true` for test)

### Seal all nodes (test vs production)

- **Test (containers):** In `group_vars/test.yml`: `vault_seal_standbys_by_restart: true`, `vault_seal_restart_command: "docker restart {{ inventory_hostname }}"`
- **Production (VMs):** In `group_vars/production.yml`: `vault_seal_standbys_by_restart: true`, `vault_seal_restart_command: "systemctl restart vault"`

## Security

- **Root token** and **unseal keys** are never printed in playbook output (`no_log` on all tasks that read, set, or send them).
- Keys and token are written to `~/.vault_keys` and `~/.vault_root_token` with mode `0600`. Secure these files immediately after init.
- For production: use TLS (`vault_skip_verify: false`), secure key storage, and restrict network access. See `PRODUCTION_READINESS.md` if present.

## Troubleshooting

- **Connection refused** – Ensure Vault is running and the correct port (test: 18200 for vault-1).
- **Policies not created with `vault_policies_use_all: true`** – When using `-i inventories/test`, put `vault_policies_use_all: true` in **`inventories/group_vars/test.yml`** so the test group gets the flag.
- **Only one node sealed** – By design, the seal API only affects the active node. To seal standbys, set `vault_seal_standbys_by_restart` and `vault_seal_restart_command` as above.
- **Permission denied on Raft dirs (macOS/Docker)** – Run `./test-env-resources/fix-permissions.sh`; chown in init containers is non-fatal.

## Test environment details

- **Containers:** vault-1, vault-2, vault-3 (ports 18200, 18202, 18204), LDAP.
- **Start:** `./test-env-resources/start-test-env.sh` or `docker compose up -d`
- **Stop:** `docker compose down`
- **Logs:** `docker compose logs -f vault-1`

## License

MIT – see LICENSE file.
