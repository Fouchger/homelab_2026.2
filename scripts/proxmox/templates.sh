#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/proxmox/templates.sh
# Created: 2026-01-18
# Description: Download and refresh commonly used Proxmox templates and images.
# Usage:
#   make proxmox.templates
# Developer notes:
#   - Runs remotely on the Proxmox node via SSH.
#   - Safe-by-default: downloads only; does not create VMs/LXCs.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/lib/ui.sh"

run_init "proxmox-templates"
state_init
ui_ensure_ui_deps

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

PROXMOX_HOST="${PROXMOX_HOST:-192.168.88.250}"
PROXMOX_SSH_USER="${PROXMOX_SSH_USER:-root}"
PROXMOX_SSH_PORT="${PROXMOX_SSH_PORT:-22}"

storage="$(state_get pve_storage 'local')"
storage="$(ui_input 'Proxmox Templates' 'Which Proxmox storage should receive templates? (e.g. local, local-lvm, fast-ssd)' "${storage}")"
state_set pve_storage "${storage}"

selected=""
ui_checklist "Templates" "Select templates/images to download" selected \
  ubuntu2404 "🟧 Ubuntu 24.04 LXC (latest)" on \
  debian12 "🟥 Debian 12 LXC (latest)" on \
  ubuntu_cloud "☁️ Ubuntu 24.04 cloud image (qcow2/img)" on \
  debian_cloud "☁️ Debian 12 generic cloud image (qcow2)" off

info "Target Proxmox: ${PROXMOX_SSH_USER}@${PROXMOX_HOST}:${PROXMOX_SSH_PORT}"
info "Storage: ${storage}"
info "Selection: ${selected}"

ssh -p "${PROXMOX_SSH_PORT}" "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
  "STORE=${storage} SEL=${selected} bash -s" <<'EOS'
set -Eeuo pipefail
STORE="${STORE}"
SEL="${SEL}"

command -v pveam >/dev/null 2>&1 || { echo "pveam not found. Are you on a Proxmox node?"; exit 1; }
command -v wget >/dev/null 2>&1 || { apt-get update -y && apt-get install -y wget; }

echo "Updating template lists..."
pveam update

action_has() { echo "${SEL}" | grep -qw "$1"; }

ensure_template() {
  local template
  template="$1"
  echo "Downloading LXC template: ${template} -> ${STORE}"
  pveam download "${STORE}" "${template}"
}

download_cloud_image() {
  local url name
  url="$1"; name="$2"
  mkdir -p "/var/lib/vz/template/iso"
  echo "Downloading cloud image: ${name}"
  wget -q --show-progress -O "/var/lib/vz/template/iso/${name}" "${url}"
}

if action_has ubuntu2404; then
  tpl="$(pveam available -section system | awk '/ubuntu-24\.04.*amd64/ {print $2}' | sort -V | tail -n1)"
  [ -n "${tpl}" ] && ensure_template "${tpl}" || echo "Ubuntu 24.04 LXC template not found in pveam catalogue."
fi

if action_has debian12; then
  tpl="$(pveam available -section system | awk '/debian-12.*amd64/ {print $2}' | sort -V | tail -n1)"
  [ -n "${tpl}" ] && ensure_template "${tpl}" || echo "Debian 12 LXC template not found in pveam catalogue."
fi

if action_has ubuntu_cloud; then
  download_cloud_image "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" "ubuntu-24.04-noble-cloudimg-amd64.img"
fi

if action_has debian_cloud; then
  download_cloud_image "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" "debian-12-bookworm-genericcloud-amd64.qcow2"
fi

echo "Done."
EOS

ok "Templates/images refresh completed."
