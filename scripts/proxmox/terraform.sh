#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/proxmox/terraform.sh
# Created: 2026-01-18
# Description: Wrapper for Terraform actions against Proxmox.
# Usage:
#   scripts/proxmox/terraform.sh plan|apply|destroy
# Developer notes:
#   - Reads configuration from ~/.config/homelab_2026_2/state.env.
#   - Expects a Proxmox API token file created by scripts/proxmox/bootstrap-api-token.sh.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/lib/ui.sh"

run_init "terraform"
state_init

# Configuration validation (opt-out)
if [[ "${SKIP_VALIDATE:-no}" != "yes" ]]; then
  "${REPO_ROOT}/scripts/core/validate.sh" || exit $?
fi

ACTION="${1:-plan}"
case "${ACTION}" in plan|apply|destroy) : ;; *) error "Unknown action: ${ACTION}"; exit 2;; esac

need_cmd terraform || {
  warn "Terraform is not installed on this node."
  if ui_confirm "Terraform" "Install Terraform now (Debian/Ubuntu via apt)?" "yes"; then
    apt_install gnupg lsb-release
    # HashiCorp official repo install (safe for Debian/Ubuntu)
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y terraform
  else
    exit 1
  fi
}

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

PROXMOX_HOST="${PROXMOX_HOST:-192.168.88.250}"
PVE_USER_NAME="${PVE_USER_NAME:-homelab_automation}"
PVE_TOKEN_ID="${PVE_TOKEN_ID:-homelab_automation_api}"
TOKEN_OUT_DIR="${TOKEN_OUT_DIR:-$HOME/.proxmox}"
TOKEN_FILE="${TOKEN_OUT_FILE:-${TOKEN_OUT_DIR}/${PROXMOX_HOST}_${PVE_USER_NAME}_${PVE_TOKEN_ID}.token}"

if [[ ! -r "${TOKEN_FILE}" ]]; then
  error "Proxmox token file not found: ${TOKEN_FILE}"
  error "Run: make proxmox.token"
  exit 1
fi

# Token file format: export PM_API_TOKEN_ID=... and export PM_API_TOKEN_SECRET=...
# shellcheck disable=SC1090
source "${TOKEN_FILE}"
# Export TF_VARs from state and token so Terraform can run non-interactively.
export TF_VAR_proxmox_host="${PROXMOX_HOST}"
export TF_VAR_proxmox_api_url="${PROXMOX_API_URL:-https://${PROXMOX_HOST}:8006/api2/json}"
export TF_VAR_proxmox_token_id="${PM_API_TOKEN_ID:-}"
export TF_VAR_proxmox_token_secret="${PM_API_TOKEN_SECRET:-}"
export TF_VAR_node_name="${PROXMOX_NODE:-pve01}"
services_raw="${DESIRED_SERVICES:-admin dns dhcp}"
services_json='['
first=1
for s in ${services_raw}; do
  if [[ "$first" -eq 1 ]]; then
    services_json+="\"${s}\""
    first=0
  else
    services_json+=",\"${s}\""
  fi
done
services_json+=']'
export TF_VAR_target_services="${services_json}"

export TF_VAR_lan_cidr="${LAN_CIDR:-192.168.88.0/24}"
export TF_VAR_lan_gateway="${LAN_GATEWAY:-192.168.88.1}"
export TF_VAR_lan_domain="${LAN_DOMAIN:-home.arpa}"
export TF_VAR_bridge="${PROXMOX_BRIDGE:-vmbr0}"
export TF_VAR_storage="${PROXMOX_STORAGE:-local-lvm}"
export TF_VAR_template_datastore_id="${PROXMOX_TEMPLATE_STORAGE:-local}"

# SSH key used for initial access to Terraform-provisioned LXCs.
SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}"
if [[ ! -r "${SSH_PUBKEY_FILE}" ]]; then
  warn "SSH public key not found at ${SSH_PUBKEY_FILE}."
  if ui_confirm "SSH Key" "Generate a new ed25519 SSH keypair now?" "yes"; then
    mkdir -p "$(dirname -- "${SSH_PUBKEY_FILE}")"
    ssh-keygen -t ed25519 -N "" -f "${SSH_PUBKEY_FILE%.pub}" >/dev/null
    success "Generated SSH keypair: ${SSH_PUBKEY_FILE%.pub}"
  else
    error "Cannot continue without an SSH public key. Provide SSH_PUBKEY_FILE or create ~/.ssh/id_ed25519.pub."
    exit 1
  fi
fi

export TF_VAR_ssh_public_key="$(cat "${SSH_PUBKEY_FILE}")"


TF_DIR="${REPO_ROOT}/terraform"

info "Terraform dir: ${TF_DIR}"
info "Action: ${ACTION}"

cd "${TF_DIR}"
terraform init -upgrade

case "${ACTION}" in
  plan)
    terraform plan
    ;;
  apply)
    terraform apply -auto-approve
    "${REPO_ROOT}/scripts/core/render-inventory.sh" || true
    ;;
  destroy)
    if ui_confirm "Destroy" "This will destroy Terraform-managed VMs/LXCs. Continue?" "no"; then
      terraform destroy -auto-approve
    else
      warn "Destroy cancelled."
    fi
    ;;
esac
