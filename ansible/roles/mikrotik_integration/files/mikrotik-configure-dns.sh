#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: ansible/roles/mikrotik_integration/files/mikrotik-configure-dns.sh
# Created: 2026-01-19
# Description: Configure MikroTik DHCP DNS advertisement for dns01 + dns02.
# Usage:
#   /opt/homelab/mikrotik/configure-dns.sh
# Developer notes:
#   - Designed to be run manually, not scheduled.
#   - Uses SSH key auth preferred; password via MIKROTIK_SSH_PASSWORD.
# ----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

log_ts() { date -Is; }
log() { printf '%s %s\n' "$(log_ts)" "$*"; }

STATE_ENV="/root/.config/homelab_2026_2/state.env"
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

need() { command -v "$1" >/dev/null 2>&1 || { log "ERROR missing dependency: $1"; exit 1; }; }
need ssh

ssh_args=("-p" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new" "-o" "ConnectTimeout=10")
if [[ -n "${MT_KEY}" && -r "${MT_KEY}" ]]; then
  ssh_args+=("-i" "${MT_KEY}")
fi

run_remote() {
  local cmd="$1"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    need sshpass
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  else
    ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  fi
}

log "INFO Setting DHCP network DNS servers for ${LAN_CIDR} -> ${DNS_LIST}"
run_remote "/ip dhcp-server network set [find address=${LAN_CIDR}] dns-server=${DNS_LIST}"

log "INFO Setting router DNS upstream servers -> ${DNS_LIST}"
run_remote "/ip dns set servers=${DNS_LIST} allow-remote-requests=yes"

log "OK MikroTik DNS advertisement updated"
