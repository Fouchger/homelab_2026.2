#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/backup.sh
# Created: 2026-01-19
# Description: Create RouterOS backups (export + binary backup) and pull them
#              to the local machine.
# Usage:
#   scripts/mikrotik/backup.sh
# Developer notes:
#   - Designed to run from admin01, but can run anywhere with network access.
#   - Prefers SSH key auth. If password auth is used, supply MIKROTIK_SSH_PASSWORD
#     at runtime (do not store it in state.env).
#   - Backup artefacts are stored under ~/.config/homelab_2026_2/mikrotik/backups.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"

run_init "mikrotik_backup"
state_init

need_cmd ssh
need_cmd scp

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

MT_HOST="${MIKROTIK_HOST:-${LAN_GATEWAY:-192.168.88.1}}"
MT_USER="${MIKROTIK_SSH_USER:-admin}"
MT_PORT="${MIKROTIK_SSH_PORT:-22}"
MT_KEY="${MIKROTIK_SSH_KEY_PATH:-}"

BACKUP_ROOT="${HOME}/.config/homelab_2026_2/mikrotik/backups"
RETENTION_COUNT="${MIKROTIK_BACKUP_RETENTION_COUNT:-30}"
TS="$(date +%Y%m%d_%H%M%S)"
PREFIX="mikrotik_${MT_HOST}_${TS}"

mkdir -p "${BACKUP_ROOT}"

ssh_args=("-p" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new")
scp_args=("-P" "${MT_PORT}" "-o" "StrictHostKeyChecking=accept-new")

if [[ -n "${MT_KEY}" ]]; then
  ssh_args+=("-i" "${MT_KEY}")
  scp_args+=("-i" "${MT_KEY}")
fi

if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
  need_cmd sshpass
fi

run_remote() {
  local cmd="$1"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  else
    ssh "${ssh_args[@]}" "${MT_USER}@${MT_HOST}" "$cmd"
  fi
}

pull_file() {
  local remote_path="$1"
  local local_path="$2"
  if [[ -n "${MIKROTIK_SSH_PASSWORD:-}" ]]; then
    sshpass -p "${MIKROTIK_SSH_PASSWORD}" scp "${scp_args[@]}" "${MT_USER}@${MT_HOST}:${remote_path}" "${local_path}"
  else
    scp "${scp_args[@]}" "${MT_USER}@${MT_HOST}:${remote_path}" "${local_path}"
  fi
}

info "Creating RouterOS export and system backup on ${MT_HOST}"

# Ensure we have a predictable file naming convention.
run_remote "/export file=${PREFIX}"
run_remote "/system backup save name=${PREFIX}"

# RouterOS typically creates files at the root of its file system.
EXPORT_LOCAL="${BACKUP_ROOT}/${PREFIX}.rsc"
BACKUP_LOCAL="${BACKUP_ROOT}/${PREFIX}.backup"

info "Downloading export to ${EXPORT_LOCAL}"
pull_file "${PREFIX}.rsc" "${EXPORT_LOCAL}"

info "Downloading backup to ${BACKUP_LOCAL}"
pull_file "${PREFIX}.backup" "${BACKUP_LOCAL}"

# Optional cleanup on the router (keeps storage tidy).
if [[ "${MIKROTIK_BACKUP_CLEANUP:-yes}" = "yes" ]]; then
  info "Cleaning up remote backup files"
  run_remote "/file remove ${PREFIX}.rsc"
  run_remote "/file remove ${PREFIX}.backup"
fi

ok "MikroTik backup completed. Stored under: ${BACKUP_ROOT}"

prune_backups() {
  local keep="${1}"
  [[ "${keep}" =~ ^[0-9]+$ ]] || keep=30
  if [[ "${keep}" -le 0 ]]; then
    warn "Backup retention disabled (MIKROTIK_BACKUP_RETENTION_COUNT=${keep})."
    return 0
  fi

  # We prune by unique backup prefix so export+binary pairs are kept together.
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

  ok "Applied retention policy: kept last ${keep} backup sets for ${MT_HOST}."
}

prune_backups "${RETENTION_COUNT}"
