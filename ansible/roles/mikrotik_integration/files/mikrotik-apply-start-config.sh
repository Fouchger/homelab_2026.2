#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: ansible/roles/mikrotik_integration/files/mikrotik-apply-start-config.sh
# Created: 2026-01-19
# Description: Standalone helper to import a RouterOS RSC file into MikroTik.
# Usage:
#   /opt/homelab/mikrotik/apply-start-config.sh /path/to/config.rsc
# Developer notes:
#   - Potentially disruptive. This script requires explicit confirmation.
#   - Set CONFIRM=YES to proceed (prevents accidental runs).
# -----------------------------------------------------------------------------

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

config_path="${1:-/root/.config/homelab_2026_2/mikrotik/start_config.rsc}"

if [[ "${CONFIRM:-NO}" != "YES" ]]; then
  log "ERROR Refusing to run without CONFIRM=YES"
  exit 1
fi

if [[ ! -f "${config_path}" ]]; then
  log "ERROR Config file not found: ${config_path}"
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { log "ERROR missing dependency: $1"; exit 1; }; }
need ssh
need scp

ssh_args=("-p" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new")
scp_args=("-P" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new")

if [[ -n "${MT_KEY}" ]]; then
  ssh_args+=("-i" "${MT_KEY}")
  scp_args+=("-i" "${MT_KEY}")
fi

if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
  need sshpass
fi

run_remote() {
  local cmd="$1"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  else
    ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  fi
}

push_file() {
  local local_path="$1"
  local remote_path="$2"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" scp "${scp_args[@]}" "${local_path}" "${MT_USER}@${MT_HOST}:${remote_path}"
  else
    scp "${scp_args[@]}" "${local_path}" "${MT_USER}@${MT_HOST}:${remote_path}"
  fi
}

remote_name="homelab_start_$(date +%Y%m%d_%H%M%S).rsc"
log "INFO Uploading ${config_path} to ${MT_HOST}:${remote_name}"
push_file "${config_path}" "${remote_name}"

log "INFO Importing configuration on ${MT_HOST}"
run_remote "/import file=${remote_name}"

if [[ "${MIKROTIK_START_CONFIG_CLEANUP:-yes}" = "yes" ]]; then
  run_remote "/file remove ${remote_name}" || true
fi

log "OK Imported start configuration into ${MT_HOST}"
