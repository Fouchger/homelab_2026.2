#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/ansible.sh
# Created: 2026-01-18
# Updated: 2026-01-19
# Description: Run homelab_2026.2 Ansible playbooks.
# Usage:
#   make ansible
# Developer notes:
#   - Inventory defaults to inventories/local.ini unless overridden.
#   - Secrets are injected at runtime via Vaultwarden + SOPS (optional).
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"

run_init "ansible"
state_init

# Configuration validation (opt-out)
if [[ "${SKIP_VALIDATE:-no}" != "yes" ]]; then
  "${REPO_ROOT}/scripts/core/validate.sh" || exit $?
fi

need_cmd ansible-playbook || exit 1

DEFAULT_INV="${REPO_ROOT}/inventories/generated.yml"
if [[ ! -r "${DEFAULT_INV}" ]]; then
  DEFAULT_INV="${REPO_ROOT}/inventories/local.ini"
fi

INV_FILE="${INVENTORY_FILE:-${DEFAULT_INV}}"
PLAYBOOK="${PLAYBOOK:-${REPO_ROOT}/ansible/site.yml}"

# Load persisted state (dotenv). All keys are stored as uppercase variables.
STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

# Map state to Ansible variables.
HOMELAB_DNS_PROVIDER="${DNS_PROVIDER:-bind9}"
HOMELAB_DHCP_MODE="${DHCP_MODE:-mikrotik}"
HOMELAB_LAN_DOMAIN="${LAN_DOMAIN:-home.arpa}"
HOMELAB_LAN_CIDR="${LAN_CIDR:-192.168.88.0/24}"
HOMELAB_LAN_GATEWAY="${LAN_GATEWAY:-192.168.88.1}"

# DNS node IPs are needed for MikroTik advertisement and health checks.
HOMELAB_DNS01_IP="${DNS01_IP:-192.168.88.2}"
HOMELAB_DNS02_IP="${DNS02_IP:-192.168.88.3}"

# MikroTik connection details.
HOMELAB_MIKROTIK_HOST="${MIKROTIK_HOST:-${HOMELAB_LAN_GATEWAY}}"
HOMELAB_MIKROTIK_SSH_USER="${MIKROTIK_SSH_USER:-admin}"
HOMELAB_MIKROTIK_SSH_PORT="${MIKROTIK_SSH_PORT:-22}"
HOMELAB_MIKROTIK_SSH_KEY_PATH="${MIKROTIK_SSH_KEY_PATH:-}"

info "Inventory: ${INV_FILE}"
info "Playbook: ${PLAYBOOK}"

# Optional secrets wiring (Vaultwarden + SOPS).
ANSIBLE_SECRETS_ARGS=()
if [[ -r "${REPO_ROOT}/scripts/secrets/runtime.sh" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/scripts/secrets/runtime.sh"
fi

ansible-playbook -i "${INV_FILE}" "${PLAYBOOK}" \
  -e "homelab_dns_provider=${HOMELAB_DNS_PROVIDER}" \
  -e "homelab_dhcp_mode=${HOMELAB_DHCP_MODE}" \
  -e "homelab_lan_domain=${HOMELAB_LAN_DOMAIN}" \
  -e "homelab_lan_cidr=${HOMELAB_LAN_CIDR}" \
  -e "homelab_lan_gateway=${HOMELAB_LAN_GATEWAY}" \
  -e "homelab_dns01_ip=${HOMELAB_DNS01_IP}" \
  -e "homelab_dns02_ip=${HOMELAB_DNS02_IP}" \
  -e "homelab_mikrotik_host=${HOMELAB_MIKROTIK_HOST}" \
  -e "homelab_mikrotik_ssh_user=${HOMELAB_MIKROTIK_SSH_USER}" \
  -e "homelab_mikrotik_ssh_port=${HOMELAB_MIKROTIK_SSH_PORT}" \
  -e "homelab_mikrotik_ssh_key_path=${HOMELAB_MIKROTIK_SSH_KEY_PATH}" \
  "${ANSIBLE_SECRETS_ARGS[@]}" \
  "$@"
