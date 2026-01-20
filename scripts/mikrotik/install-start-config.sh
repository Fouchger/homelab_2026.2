#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/install-start-config.sh
# Created: 2026-01-19
# Description: Convenience helper to place a RouterOS start config into the
#              expected local path (git-safe).
# Usage:
#   scripts/mikrotik/install-start-config.sh
# Developer notes:
#   - Copies an RSC file from the repo's .local/ directory (gitignored) into:
#       ~/.config/homelab_2026_2/mikrotik/start_config.rsc
#   - This does NOT apply the config to MikroTik. Use apply-start-config.sh.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/lib/ui.sh"

run_init "mikrotik_install_start_config"
state_init

SRC_DEFAULT="${REPO_ROOT}/.local/mikrotik_start_config_20260119.rsc"
DEST_DIR="${HOME}/.config/homelab_2026_2/mikrotik"
DEST_FILE="${DEST_DIR}/start_config.rsc"

src="${1:-${SRC_DEFAULT}}"

if [[ ! -f "${src}" ]]; then
  fail "Start config source not found: ${src}"
  info "Put your exported RouterOS .rsc under ${REPO_ROOT}/.local/ or pass a path as the first argument."
  exit 1
fi

if ! ui_confirm "MikroTik" "Copy start config to ${DEST_FILE}?" "yes"; then
  warn "Cancelled."
  exit 0
fi

mkdir -p "${DEST_DIR}"
cp -f "${src}" "${DEST_FILE}"
chmod 0600 "${DEST_FILE}" || true

ok "Installed start config to ${DEST_FILE} (local-only)."
