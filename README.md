# HashiCorp Vault Ansible Configuration

A comprehensive, modular Ansible playbook for configuring HashiCorp Vault with support for initialization, audit logging, and policy management. Each component can be run independently or as part of a complete configuration.

## Features

- **Modular Design**: Each role can be executed independently
- **Vault Initialization**: Automated initialization and unsealing
- **Audit Logging**: Configurable audit logging to specified paths  
- **Policy Management**: Create and manage Vault policies from files or inline definitions
- **Test Environment**: Docker Compose setup for testing
- **Production Ready**: Separate inventories and configurations for different environments

## Project Structure

```
vault-initializer/
├── ansible.cfg                    # Ansible configuration
├── site.yml                       # Main playbook (all roles)
├── docker-compose.yml             # Test environment setup
├── setup-test-env.sh             # Test environment helper script
├── run-playbook.sh               # Convenient playbook runner
├── group_vars/
│   └── all.yml                   # Global variables
├── inventories/
│   ├── production                # Production inventory
│   └── test                      # Test inventory
├── playbooks/
│   ├── init-only.yml            # Vault initialization only
│   ├── audit-only.yml           # Audit configuration only
│   └── policies-only.yml        # Policy management only
├── roles/
│   ├── vault-init/              # Vault initialization role
│   ├── vault-audit/             # Audit logging role
│   └── vault-policies/          # Policy management role
├── policies/                     # Policy files directory (created automatically)
└── test-config/
    └── vault.hcl                # Vault configuration for testing
```

## Quick Start

### 1. Set up Test Environment

```bash
# Start the test Vault environment
./setup-test-env.sh

# Or manually with Docker Compose
docker-compose up -d
```

### 2. Run Complete Configuration

```bash
# Configure everything (test environment)
./run-playbook.sh all

# Or use ansible-playbook directly
ansible-playbook -i inventories/test site.yml
```

### 3. Run Individual Components

```bash
# Initialize Vault only
./run-playbook.sh init

# Configure audit logging only  
./run-playbook.sh audit

# Configure policies only
./run-playbook.sh policies
```

## Roles

### vault-init

Handles Vault initialization and unsealing.

**Features:**
- Checks if Vault is already initialized
- Initializes Vault with configurable key shares and threshold
- Saves unseal keys and root token securely
- Automatically unseals Vault
- Verifies Vault health

**Variables:**
```yaml
vault_key_threshold: 3          # Number of keys needed to unseal
vault_key_shares: 5             # Total number of unseal keys
vault_auto_unseal_on_init: true # Auto-unseal after initialization
vault_force_init: false        # Force re-initialization
```

### vault-audit

Configures audit logging for Vault.

**Features:**
- Enables file-based audit logging
- Creates audit log directories with proper permissions
- Supports multiple audit devices
- Configurable audit paths and options

**Variables:**
```yaml
vault_audit_devices:
  - device_type: "file"
    path: "file_audit" 
    description: "File-based audit logging"
    options:
      file_path: "/vault/logs/audit.log"
      log_raw: false
      hmac_accessor: true
      mode: "0600"

vault_audit_log_dir: "/vault/logs"
vault_audit_remove_existing: false  # Remove existing audit devices
vault_audit_force_enable: false     # Force enable even if exists
```

### vault-policies

Manages Vault policies from files or inline definitions.

**Features:**
- Creates policies from files in `policies/` directory
- Supports inline policy definitions
- Validates policy syntax before applying
- Creates default policies (admin, read-only, app-secrets, kv-reader)
- Generates usage examples

**Variables:**
```yaml
vault_policies_source_dir: "{{ playbook_dir }}/policies"
vault_policies_create_default: true
vault_policies_update_existing: false
vault_policies_validate_syntax: true

vault_custom_policies:
  - name: "my-custom-policy"
    content: |
      path "secret/data/myapp/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }
```

## Configuration

### Global Variables (`group_vars/all.yml`)

Key configuration options:

```yaml
# Vault connection
vault_addr: "http://localhost:8200"
vault_token: ""
vault_skip_verify: true

# Initialization
vault_key_threshold: 3
vault_key_shares: 5

# Audit logging  
vault_audit_enabled: true
vault_audit_path: "/vault/logs/audit.log"

# Default policies
vault_default_policies:
  - name: "admin"
    content: |
      path "*" {
        capabilities = ["create", "read", "update", "delete", "list", "sudo"]
      }
```

### Environment-Specific Configuration

Override variables in inventory files or create environment-specific variable files:

```yaml
# inventories/production
[vault_servers]
vault-prod-1 ansible_host=10.0.1.10
vault-prod-2 ansible_host=10.0.1.11

[vault_servers:vars]
vault_addr=https://vault.company.com:8200
vault_skip_verify=false
vault_audit_log_dir=/var/log/vault
```

## Usage Examples

### Basic Usage

```bash
# Complete setup for test environment
./run-playbook.sh all

# Production deployment
./run-playbook.sh prod-all
```

### Individual Role Execution

```bash
# Initialize production Vault
ansible-playbook -i inventories/production playbooks/init-only.yml

# Configure audit logging with custom path
ansible-playbook -i inventories/test playbooks/audit-only.yml \
  -e vault_audit_path="/custom/audit/path.log"

# Update policies only
ansible-playbook -i inventories/production playbooks/policies-only.yml \
  -e vault_policies_update_existing=true
```

### Using Tags

```bash
# Run specific components using tags
ansible-playbook -i inventories/test site.yml --tags "init,audit"
ansible-playbook -i inventories/test site.yml --tags "policies"
```

### Custom Policy Management

```bash
# Add custom policies directory
ansible-playbook -i inventories/test playbooks/policies-only.yml \
  -e vault_policies_source_dir="/path/to/custom/policies"

# Skip default policies, use only custom
ansible-playbook -i inventories/test playbooks/policies-only.yml \
  -e vault_policies_create_default=false \
  -e vault_custom_policies='[{"name":"my-policy","content":"path \"secret/*\" { capabilities=[\"read\"] }"}]'
```

## Security Considerations

### Key Management

- **Unseal Keys**: Stored in `~/.vault_keys` with 600 permissions
- **Root Token**: Stored in `~/.vault_root_token` with 600 permissions
- **Important**: Secure these files immediately after initialization

### Production Recommendations

1. **Use TLS**: Set `vault_skip_verify: false` and configure proper certificates
2. **Secure Key Storage**: Move unseal keys to secure locations (HSM, separate systems)
3. **Rotate Root Token**: Create new tokens and revoke the root token
4. **Network Security**: Restrict network access to Vault servers
5. **Audit Logs**: Monitor and rotate audit logs regularly

### Policy Best Practices

1. **Principle of Least Privilege**: Grant minimum required permissions
2. **Path-based Policies**: Use specific paths rather than wildcards
3. **Regular Review**: Audit policies regularly
4. **Testing**: Test policies in non-production environments

## Advanced Configuration

### Custom Audit Devices

```yaml
vault_audit_devices:
  - device_type: "file"
    path: "file_audit_1"
    options:
      file_path: "/vault/logs/audit.log"
  - device_type: "file"  
    path: "file_audit_2"
    options:
      file_path: "/vault/logs/audit-backup.log"
      log_raw: true
```

### Multiple Policy Sources

Create policy files in the `policies/` directory:

```bash
# policies/database-policy.hcl
path "database/creds/readonly" {
  capabilities = ["read"]
}

# policies/app-policy.hcl  
path "secret/data/app/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

### Environment Variables

Set environment variables for sensitive data:

```bash
export VAULT_ROOT_TOKEN="s.xxxxxxxxx"
ansible-playbook -i inventories/production site.yml -e vault_root_token="$VAULT_ROOT_TOKEN"
```

## Troubleshooting

### Common Issues

1. **Connection Refused**: Ensure Vault is running and accessible
2. **Permission Denied**: Check that unseal keys and root token are available
3. **Policy Validation Failed**: Review policy syntax in HCL format
4. **Audit Device Already Exists**: Set `vault_audit_force_enable: true` or `vault_audit_remove_existing: true`

### Debug Mode

```bash
# Enable verbose output
ansible-playbook -i inventories/test site.yml -vvv

# Check specific role
ansible-playbook -i inventories/test playbooks/init-only.yml --check --diff
```

### Vault Status Commands

```bash
# Check Vault status
curl -s http://localhost:8200/v1/sys/health

# List policies (requires token)
curl -s -H "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  http://localhost:8200/v1/sys/policies/acl | jq

# List audit devices
curl -s -H "X-Vault-Token: $VAULT_ROOT_TOKEN" \
  http://localhost:8200/v1/sys/audit | jq
```

## Test Environment

The included Docker Compose setup provides:

- **Production-like Vault** (`localhost:8200`): File storage, requires initialization
- **Development Vault** (`localhost:8201`): Dev mode, pre-initialized (token: `devroot`)

### Test Environment Commands

```bash
# Start test environment
./setup-test-env.sh

# Check services
docker-compose ps

# View logs
docker-compose logs vault

# Stop environment
docker-compose down

# Clean up (remove volumes)
docker-compose down -v
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the provided test environment
5. Submit a pull request

## License

MIT License - see LICENSE file for details.