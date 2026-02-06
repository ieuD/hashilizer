# Vault Ansible Playbook Runner
# Usage: make <target>   e.g. make init, make all, make prod-all
# Optional: source .venv/bin/activate (or vault-ansible/bin/activate) before running.

SHELL := /bin/bash
ANSIBLE := ansible-playbook
TEST_INV := -i inventories/test
PROD_INV := -i inventories/production

# Run playbook with optional venv activation (activation + ansible in same shell)
define run_test
	( [ -d .venv ] && . .venv/bin/activate; [ -d vault-ansible ] && . vault-ansible/bin/activate; $(ANSIBLE) $(TEST_INV) $1 )
endef
define run_prod
	( [ -d .venv ] && . .venv/bin/activate; [ -d vault-ansible ] && . vault-ansible/bin/activate; $(ANSIBLE) $(PROD_INV) $1 )
endef

.PHONY: help init unseal seal audit policies all \
	prod-init prod-unseal prod-seal prod-audit prod-policies prod-all

# Default target
.DEFAULT_GOAL := help

help:
	@echo "Vault Ansible Playbook Runner"
	@echo "=============================="
	@echo ""
	@echo "Test (3-node Raft cluster):"
	@echo "  make init       - Initialize Vault (node 1 only)"
	@echo "  make unseal     - Unseal all 3 nodes (run after init)"
	@echo "  make seal       - Seal all 3 nodes"
	@echo "  make audit      - Configure audit logging only"
	@echo "  make policies   - Configure policies only"
	@echo "  make all        - Run complete configuration"
	@echo ""
	@echo "Production:"
	@echo "  make prod-init     - Initialize Vault only (production)"
	@echo "  make prod-unseal   - Unseal Vault (production)"
	@echo "  make prod-seal     - Seal Vault (production)"
	@echo "  make prod-audit    - Configure audit logging only (production)"
	@echo "  make prod-policies - Configure policies only (production)"
	@echo "  make prod-all      - Run complete configuration (production)"

# --- Test targets ---
init:
	@echo "Running Vault initialization (node 1 only)..."
	@$(call run_test,playbooks/init-only.yml --limit vault-1)

unseal:
	@echo "Unsealing all Vault nodes..."
	@$(call run_test,playbooks/unseal-only.yml)

seal:
	@echo "Sealing all Vault nodes..."
	@$(call run_test,playbooks/seal-only.yml)

audit:
	@echo "Running Vault audit configuration..."
	@$(call run_test,playbooks/audit-only.yml)

policies:
	@echo "Running Vault policy configuration..."
	@$(call run_test,playbooks/policies-only.yml)

all:
	@echo "Running complete Vault configuration..."
	@$(call run_test,site.yml)

# --- Production targets ---
prod-init:
	@echo "Running Vault initialization (Production)..."
	@$(call run_prod,playbooks/init-only.yml)

prod-unseal:
	@echo "Unsealing Vault (Production)..."
	@$(call run_prod,playbooks/unseal-only.yml)

prod-seal:
	@echo "Sealing Vault (Production)..."
	@$(call run_prod,playbooks/seal-only.yml)

prod-audit:
	@echo "Running Vault audit configuration (Production)..."
	@$(call run_prod,playbooks/audit-only.yml)

prod-policies:
	@echo "Running Vault policy configuration (Production)..."
	@$(call run_prod,playbooks/policies-only.yml)

prod-all:
	@echo "Running complete Vault configuration (Production)..."
	@$(call run_prod,playbooks/site.yml)
