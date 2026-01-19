#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/apply-start-config.sh
# Created: 2026-01-19
# Description: Apply a RouterOS baseline configuration (RSC) to MikroTik.
# Usage:
#   scripts/mikrotik/apply-start-config.sh
# Developer notes:
#   - This is opt-in and potentially disruptive. Always review the RSC first.
#   - The script looks for a local config file path defined by:
#       MIKROTIK_START_CONFIG_PATH (preferred) or
#       ~/.config/homelab_2026_2/mikrotik/start_config.rsc
#   - The repository ships a LOCAL-ONLY example under .local/ for convenience,
#     but .local/ is gitignored to prevent leaking device identifiers.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/lib/ui.sh"

run_init "mikrotik_apply_start_config"
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

CONFIG_PATH_DEFAULT="${HOME}/.config/homelab_2026_2/mikrotik/start_config.rsc"
CONFIG_PATH="${MIKROTIK_START_CONFIG_PATH:-${CONFIG_PATH_DEFAULT}}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  fail "Start config not found: ${CONFIG_PATH}"
  info "Tip: copy your .rsc file to ${CONFIG_PATH_DEFAULT} or set MIKROTIK_START_CONFIG_PATH."
  exit 1
fi

if ! ui_confirm "MikroTik" "This will import a RouterOS configuration into ${MT_HOST}. This can change network settings. Continue?" "no"; then
  warn "Cancelled."
  exit 0
fi

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

info "Uploading ${CONFIG_PATH} to ${MT_HOST}:${remote_name}"
push_file "${CONFIG_PATH}" "${remote_name}"

info "Importing configuration on MikroTik (this may take a moment)"
run_remote "/import file=${remote_name}"

if [[ "${MIKROTIK_START_CONFIG_CLEANUP:-yes}" = "yes" ]]; then
  info "Cleaning up uploaded config file"
  run_remote "/file remove ${remote_name}" || true
fi

ok "Imported start configuration into ${MT_HOST}."
