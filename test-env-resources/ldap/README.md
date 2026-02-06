# LDAP test environment

Used for Vault LDAP auth integration in test. LDAP runs as part of the Raft compose stack.

## Structure

- **Base DN:** `dc=test,dc=local`
- **Admin:** `cn=admin,dc=test,dc=local` (password: `admin` – change in production)
- **Users OU:** `ou=users,dc=test,dc=local`
- **Service account:** `uid=sa.vault,ou=users,dc=test,dc=local` (create via `ldapadd` after stack is up)

## Start stack (Vault Raft + LDAP)

```bash
docker compose up -d
```

LDAP is on port 389; Vault nodes on 8200, 8201, 8202.

## Create sa.vault user (manual)

After the stack is up, create the user with `ldapadd` (e.g. from the `ldap` container or host with openldap-clients):

```bash
# From host (if you have ldap-utils): use -h localhost -p 389
# Or exec into container and run ldapadd with an LDIF that defines uid=sa.vault,ou=users,dc=test,dc=local
```

## Login to Vault with LDAP

Once LDAP auth is enabled in Vault and sa.vault exists:

```bash
vault login -method=ldap username=sa.vault password=<password>
```
