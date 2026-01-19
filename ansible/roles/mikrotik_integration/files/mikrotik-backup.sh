#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: ansible/roles/mikrotik_integration/files/mikrotik-backup.sh
# Created: 2026-01-19
# Description: Standalone MikroTik backup script for admin01.
# Usage:
#   /opt/homelab/mikrotik/backup.sh
# Developer notes:
#   - Reads non-sensitive connection details from /root/.config/homelab_2026_2/state.env
#   - For password auth, export MIKROTIK_SSH_PASSWORD at runtime.
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

BACKUP_ROOT="/root/.config/homelab_2026_2/mikrotik/backups"
RETENTION_COUNT="${MIKROTIK_BACKUP_RETENTION_COUNT:-30}"
mkdir -p "${BACKUP_ROOT}"

need() { command -v "$1" >/dev/null 2>&1 || { log "ERROR missing dependency: $1"; exit 1; }; }
need ssh
need scp

ssh_args=("-p" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new" "-o" "ConnectTimeout=10")
scp_args=("-P" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new" "-o" "ConnectTimeout=10")

if [[ -n "${MT_KEY}" && -r "${MT_KEY}" ]]; then
  ssh_args+=("-i" "${MT_KEY}")
  scp_args+=("-i" "${MT_KEY}")
fi

PREFIX="mikrotik_${MT_HOST}_$(date +%Y%m%d_%H%M%S)"

run_remote() {
  local cmd="$1"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    need sshpass
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  else
    ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  fi
}

pull_file() {
  local remote_path="$1"
  local local_path="$2"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    need sshpass
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" scp "${scp_args[@]}" "${MT_USER}@${MT_HOST}:${remote_path}" "${local_path}"
  else
    scp "${scp_args[@]}" "${MT_USER}@${MT_HOST}:${remote_path}" "${local_path}"
  fi
}

log "INFO Creating export + backup on ${MT_HOST}"
run_remote "/export file=${PREFIX}"
run_remote "/system backup save name=${PREFIX}"

EXPORT_LOCAL="${BACKUP_ROOT}/${PREFIX}.rsc"
BACKUP_LOCAL="${BACKUP_ROOT}/${PREFIX}.backup"

log "INFO Downloading export to ${EXPORT_LOCAL}"
pull_file "${PREFIX}.rsc" "${EXPORT_LOCAL}"

log "INFO Downloading backup to ${BACKUP_LOCAL}"
pull_file "${PREFIX}.backup" "${BACKUP_LOCAL}"

if [[ "${MIKROTIK_BACKUP_CLEANUP:-yes}" = "yes" ]]; then
  log "INFO Cleaning up remote files"
  run_remote "/file remove ${PREFIX}.rsc" || true
  run_remote "/file remove ${PREFIX}.backup" || true
fi

log "OK Backup completed in ${BACKUP_ROOT}"

prune_backups() {
  local keep="${1}"
  [[ "${keep}" =~ ^[0-9]+$ ]] || keep=30
  if [[ "${keep}" -le 0 ]]; then
    log "WARN Retention pruning disabled (MIKROTIK_BACKUP_RETENTION_COUNT=${keep})."
    return 0
  fi

  local prefixes
  prefixes=$(ls -1 "${BACKUP_ROOT}"/mikrotik_"${MT_HOST}"_*.rsc 2>/dev/null \
    | sed -E 's/\.rsc$//' \
    | sort -r || true)

  local count=0
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    count=$((count + 1))
    if [[ "${count}" -gt "${keep}" ]]; then
      rm -f "${p}.rsc" "${p}.backup" || true
    fi
  done <<<"${prefixes}"

  log "OK Applied retention policy: kept last ${keep} backup sets for ${MT_HOST}."
}

prune_backups "${RETENTION_COUNT}"
