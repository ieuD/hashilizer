# Production Readiness Checklist

This document summarizes what to do before using this Ansible codebase against production HashiCorp Vault. It is based on a full codebase analysis of playbooks, roles, inventories, and group vars.

---

## Executive summary

- **Strengths:** Modular roles (init, unseal, seal, audit, policies, auth), HA-aware seal/unseal, root token and unseal keys from files, test vs production separation.
- **Must fix for prod:** TLS, no root token in logs, production inventory and token path, optional run-playbook prod-unseal/prod-seal.
- **Recommended:** Production inventory with real hosts, Auto Unseal (KMS), backup/restore docs, and idempotency/error-handling hardening.

---

## 1. Critical fixes

### 1.1 TLS for Vault API and cluster

**Current state:** All configs use `vault_skip_verify: true` and `http://` for `vault_addr`. Test env uses `tls_disable = 1` in Vault HCL.

**For production:**

- Configure Vault servers with TLS (certificate and key) in their server config (outside this repo).
- In Ansible:
  - Set `vault_addr` to `https://...` for production (e.g. in `group_vars/production.yml` or host/group vars).
  - Set `vault_skip_verify: false` for production.
  - Use a CA bundle or proper cert validation so `uri` and Vault CLI validate the server cert.

**Where to change:** `group_vars/production.yml`, and any production-specific vars; ensure no production play runs with `vault_skip_verify: true`.

### 1.2 Do not log root token

**Current state:** `playbooks/init-only.yml` post_tasks print a summary that can include the root token:

```yaml
Root Token: {{ vault_root_token | default('(run again or check ' ~ vault_root_token_file ~ ')') }}
```

If `vault_root_token` is set in that run, it will appear in Ansible output and may end up in logs.

**For production:**

- Remove or redact the root token from any `debug`/`msg` output.
- Option: only show a message like “Root token saved to {{ vault_root_token_file }}” and never echo the token.

**Where to change:** `playbooks/init-only.yml` (and any other playbook that might print `vault_root_token`).

### 1.3 Production inventory and token/key paths

**Current state:**

- `inventories/production` is a single host: `localhost ansible_connection=local` with `vault_addr=http://localhost:8200`.
- Unseal keys and root token paths default to `~/.vault_keys` and `~/.vault_root_token` (via `ansible_facts['user_dir']` / `ansible_env.HOME`).

**For production:**

- Replace production inventory with real Vault server hostnames/IPs and correct `vault_addr` per host or group (e.g. `https://vault.example.com:8200`).
- Decide where root token and unseal keys should live (e.g. secure secret manager, not only a file on the control node). The codebase currently assumes file-based token/keys; for prod you may want to:
  - Keep using files in a restricted path and ensure only init/unseal playbooks run from a secure runner, or
  - Introduce variables that can be fed from a secret manager (e.g. `vault_root_token` / `vault_unseal_keys` set via env or vaulted vars) and avoid committing paths that assume a single shared home dir.

**Where to change:** `inventories/production`, `group_vars/production.yml` (and optionally `group_vars/vault_servers.yml` for path overrides).

### 1.4 Run-playbook production commands

**Current state:** `run-playbook.sh` has `prod-init`, `prod-audit`, `prod-policies`, `prod-all` but no `prod-unseal` or `prod-seal`.

**For production:**

- Add `prod-unseal` and `prod-seal` that call the same playbooks as test (`unseal-only.yml`, `seal-only.yml`) with `-i inventories/production`, so operators don’t have to remember the ansible-playbook invocations.

**Where to change:** `run-playbook.sh`.

---

## 2. Security

### 2.1 Secrets in group_vars

- **Test:** `group_vars/test.yml` sets `vault_token: "myroot"` and test user passwords in plain text. Acceptable for test only; ensure test vars are never used for production (production inventory should not include test group vars for prod hosts).
- **Production:** `group_vars/production.yml` correctly leaves `vault_token: ""`. Keep tokens and keys out of committed group_vars; use files or a secret manager.

### 2.2 Root token and unseal keys handling

- Roles correctly read root token and unseal keys from files when not passed in; init writes them to files. For production:
  - Restrict permissions of the token and key files (e.g. mode 0600 and only the service account that runs Ansible).
  - Prefer running init/unseal from a dedicated, locked-down host or CI job with access only to the secret store (file or secret manager).

### 2.3 Policies

- `vault_policies_update_existing: false` in production is good (avoids accidental overwrites).
- Review `policies/*.hcl` for least privilege; the `admin` policy is intentionally broad; ensure no overly broad policies are applied to prod by mistake.

### 2.4 Audit

- Production uses file audit with `mode: "0600"` and `hmac_accessor: true`. Ensure the audit log path is on durable, append-only storage and that only authorized services can read it.

---

## 3. Operational readiness

### 3.1 High availability (HA)

- Seal/unseal playbooks are HA-aware: seal-only runs per host and only seals the active node via API (standby is documented as “restart to seal”); unseal and init accept 429 (standby). For production:
  - Use an inventory that lists all Vault nodes with correct `vault_addr` per host (as in test inventory).
  - Ensure `vault_addr` in seal-only points each host to its own node (already done in `seal-only.yml` pre_tasks).

### 3.2 Idempotency and errors

- Init: Skips init if already initialized (unless `vault_force_init`); unseal is idempotent (skips if unsealed).
- Audit and policies: Generally idempotent (enable audit / put policy); 429 on standby is handled.
- Gaps:
  - No retries on transient HTTP errors in some `uri` calls; consider adding `retries`/`until` for critical calls in production.
  - Unseal role can fail the play if Vault is still sealed after unseal attempt; ensure keys and threshold are correct and that you’re targeting the correct node.

### 3.3 Auth role and standalone runs

- `vault-auth` role requires `vault_root_token`; it does not load the token from file itself. When running the full site (e.g. `prod-all`), init runs first and sets the token in the same run, so auth works. There is no standalone `auth-only.yml` playbook; if you add one, it should load the root token from file in pre_tasks (like `audit-only.yml` and `policies-only.yml`) when running against production.

### 3.4 Backup and restore

- The codebase does not implement Raft snapshot backup or restore. For production:
  - Document and/or automate `vault operator raft snapshot save` (and, if needed, restore) on the active node.
  - Consider a small playbook or script that runs snapshot save and uploads to secure storage; schedule it outside Ansible (cron or scheduler).

### 3.5 Auto Unseal (KMS)

- Production group vars set `vault_auto_unseal: true`, but the actual Vault server configuration (KMS/transit) is not managed by this repo. For production, configure Vault with KMS/Cloud Auto Unseal (or Transit) in the server config so that unseal keys are not required after restarts; then you can use this repo for init and policy/audit, and only use unseal playbook for recovery scenarios.

---

## 4. Variable and path consistency

### 4.1 Token/key file paths

- **Fixed:** `group_vars/vault_servers.yml` was using `ansible_user_dir`, which is not a standard fact on all setups. It has been aligned with role defaults using `ansible_facts['user_dir'] | default(ansible_env.HOME)` so token and key file paths resolve consistently. For production, you can still override these paths via group or host vars (e.g. a dedicated directory or path that your secret manager or runner uses).

### 4.2 Default vault_addr

- `group_vars/all.yml` and `group_vars/vault_servers.yml` use different default ports (e.g. 8202 vs 8200). Production inventory should set `vault_addr` explicitly so there is no ambiguity.

---

## 5. Optional improvements

- **Prometheus/health:** Add a small playbook or role to register a health check (e.g. `/v1/sys/health`) with your monitoring system.
- **Version pinning:** Document the minimum Vault version (and, if applicable, Ansible version) tested; the test env uses Vault 1.15.
- **Ansible:** Consider setting `ansible.cfg` inventory to a specific env (e.g. `inventory = inventories/production`) when running in prod, or always pass `-i` explicitly in run-playbook and CI.
- **Documentation:** Add a short “Production deployment” section in the main README that references this file and lists: TLS, inventory, token/key handling, backup, and Auto Unseal.

---

## 6. Quick checklist before first production run

- [ ] TLS enabled on Vault; `vault_addr` is `https://...` and `vault_skip_verify: false` for production.
- [ ] Production inventory has real hosts and correct `vault_addr` per host/group.
- [ ] Root token and unseal keys are not logged (init playbook and any summaries redacted).
- [ ] Token and key file paths are set and restricted; only the intended runner has access.
- [ ] `run-playbook.sh` has prod-unseal and prod-seal if you use them.
- [ ] Policies and audit settings reviewed for production; no test-only policies or users on prod.
- [ ] Backup/restore (Raft snapshot) and Auto Unseal (KMS/Transit) documented or implemented outside this repo.

Once these are in place, the codebase is in a good state for production use with the operational and security caveats above.
