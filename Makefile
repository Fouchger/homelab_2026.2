# -----------------------------------------------------------------------------
# homelab_2026.2 Makefile
# -----------------------------------------------------------------------------
# Developer notes:
# - Keep targets idempotent and safe-by-default.
# - Prefer calling scripts under scripts/ rather than embedding logic here.

SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z0-9_.-]+:.*##/ {printf "%-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: bootstrap
bootstrap: ## Install minimal prerequisites on a fresh node and prepare tooling
	@scripts/core/bootstrap.sh

.PHONY: menu
menu: ## Launch the interactive homelab menu
	@bin/homelab

.PHONY: validate
validate: ## Validate configuration (reads ~/.config/homelab_2026_2/state.env)
	@scripts/core/validate.sh

.PHONY: healthcheck
healthcheck: ## Run end-to-end health checks (DNS, reachability, optional HTTP)
	@scripts/core/healthcheck.sh

.PHONY: lint
lint: ## Run local quality gates (shellcheck/ansible-lint/terraform fmt)
	@scripts/core/lint.sh

.PHONY: proxmox.token
proxmox.token: ## Create or rotate Proxmox API token (Terraform/Ansible)
	@scripts/proxmox/bootstrap-api-token.sh

.PHONY: proxmox.templates
proxmox.templates: ## Download Proxmox templates and images
	@scripts/proxmox/templates.sh

.PHONY: tf.init
tf.init: ## Initialise Terraform
	@cd terraform && terraform init

.PHONY: tf.plan
tf.plan: ## Terraform plan (reads state from ~/.config/homelab_2026_2/state.env)
	@scripts/proxmox/terraform.sh plan

.PHONY: tf.apply
tf.apply: ## Terraform apply
	@scripts/proxmox/terraform.sh apply

.PHONY: tf.destroy
tf.destroy: ## Terraform destroy
	@scripts/proxmox/terraform.sh destroy

.PHONY: ansible
ansible: ## Run Ansible site playbook
	@scripts/core/ansible.sh

.PHONY: secrets.install
secrets.install: ## Install SOPS, age, and rbw (Vaultwarden compatible CLI)
	@scripts/secrets/install.sh

.PHONY: mikrotik.backup
mikrotik.backup: ## Run a MikroTik backup now
	@scripts/mikrotik/backup.sh

.PHONY: mikrotik.health
mikrotik.health: ## Run MikroTik health checks now
	@scripts/mikrotik/healthcheck.sh

.PHONY: mikrotik.advertise_dns
mikrotik.advertise_dns: ## Configure MikroTik to advertise dns01 + dns02 via DHCP
	@scripts/mikrotik/configure-dns.sh

.PHONY: mikrotik.start_config.install
mikrotik.start_config.install: ## Install local MikroTik start config into ~/.config path
	@scripts/mikrotik/install-start-config.sh

.PHONY: mikrotik.start_config.apply
mikrotik.start_config.apply: ## Apply local MikroTik start config to the router (opt-in)
	@scripts/mikrotik/apply-start-config.sh
