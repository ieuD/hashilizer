#!/bin/bash
# Quick run scripts for individual roles

# Activate virtual environment if it exists
if [ -d ".venv" ]; then
    source .venv/bin/activate
elif [ -d "vault-ansible" ]; then
    source vault-ansible/bin/activate
fi

echo "Vault Ansible Playbook Runner"
echo "=============================="

case "$1" in
  "init")
    echo "Running Vault initialization (node 1 only)..."
    ansible-playbook -i inventories/test playbooks/init-only.yml --limit vault-1
    ;;
  "unseal")
    echo "Unsealing all Vault nodes..."
    ansible-playbook -i inventories/test playbooks/unseal-only.yml
    ;;
  "seal")
    echo "Sealing all Vault nodes..."
    ansible-playbook -i inventories/test playbooks/seal-only.yml
    ;;
  "audit")
    echo "Running Vault audit configuration..."
    ansible-playbook -i inventories/test playbooks/audit-only.yml
    ;;
  "policies")
    echo "Running Vault policy configuration..."
    ansible-playbook -i inventories/test playbooks/policies-only.yml
    ;;
  "all")
    echo "Running complete Vault configuration..."
    ansible-playbook -i inventories/test site.yml
    ;;
  "prod-init")
    echo "Running Vault initialization (Production)..."
    ansible-playbook -i inventories/production playbooks/init-only.yml
    ;;
  "prod-unseal")
    echo "Unsealing Vault (Production)..."
    ansible-playbook -i inventories/production playbooks/unseal-only.yml
    ;;
  "prod-seal")
    echo "Sealing Vault (Production)..."
    ansible-playbook -i inventories/production playbooks/seal-only.yml
    ;;
  "prod-audit")
    echo "Running Vault audit configuration (Production)..."
    ansible-playbook -i inventories/production playbooks/audit-only.yml
    ;;
  "prod-policies")
    echo "Running Vault policy configuration (Production)..."
    ansible-playbook -i inventories/production playbooks/policies-only.yml
    ;;
  "prod-all")
    echo "Running complete Vault configuration (Production)..."
    ansible-playbook -i inventories/production playbooks/site.yml
    ;;
  *)
    echo "Usage: $0 {command}"
    echo ""
    echo "Test (3-node Raft cluster):"
    echo "  init              - Initialize Vault (node 1 only)"
    echo "  unseal             - Unseal all 3 nodes (run after init)"
    echo "  seal               - Seal all 3 nodes"
    echo "  audit              - Configure audit logging only"
    echo "  policies          - Configure policies only"
    echo "  all               - Run complete configuration"
    echo ""
    echo "Production:"
    echo "  prod-init         - Initialize Vault only (production)"
    echo "  prod-unseal       - Unseal Vault (production)"
    echo "  prod-seal         - Seal Vault (production)"
    echo "  prod-audit        - Configure audit logging only (production)"
    echo "  prod-policies     - Configure policies only (production)"
    echo "  prod-all          - Run complete configuration (production)"
    exit 1
    ;;
esac