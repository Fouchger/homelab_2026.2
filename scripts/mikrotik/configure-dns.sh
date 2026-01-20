#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/configure-dns.sh
# Created: 2026-01-19
# Description: Configure MikroTik DHCP advertised DNS servers and router DNS.
# Usage:
#   scripts/mikrotik/configure-dns.sh
# Developer notes:
#   - Safe, idempotent changes.
#   - Uses SSH. Supply MIKROTIK_SSH_PASSWORD at runtime if needed.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"

run_init "mikrotik_configure_dns"
state_init

need_cmd ssh

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

MT_HOST="${MIKROTIK_HOST:-${LAN_GATEWAY:-192.168.88.1}}"
MT_USER="${MIKROTIK_SSH_USER:-admin}"
MT_PORT="${MIKROTIK_SSH_PORT:-22}"
MT_KEY="${MIKROTIK_SSH_KEY_PATH:-}"

LAN_CIDR="${LAN_CIDR:-192.168.88.0/24}"
DNS1="${DNS01_IP:-192.168.88.2}"
DNS2="${DNS02_IP:-192.168.88.3}"
DNS_LIST="${DNS1},${DNS2}"

ssh_args=("-p" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new" "-o" "UserKnownHostsFile=${HOME}/.ssh/known_hosts")
[[ -n "${MT_KEY}" ]] && ssh_args+=("-i" "${MT_KEY}")

need_cmd sshpass || true

run_remote() {
  local cmd="$1"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  else
    ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  fi
}

info "Configuring MikroTik DNS advertisement for ${LAN_CIDR} -> ${DNS_LIST}"

# Configure DHCP network entry for the LAN.
# RouterOS has a list of DHCP network entries. We update the one matching our LAN.
run_remote "/ip dhcp-server network set [find where address=\"${LAN_CIDR}\"] dns-server=\"${DNS_LIST}\""

# Configure router itself to use the same DNS servers for its own lookups.
run_remote "/ip dns set servers=\"${DNS_LIST}\" allow-remote-requests=yes"

ok "MikroTik now advertises DNS servers: ${DNS_LIST} (DHCP + router DNS)."
