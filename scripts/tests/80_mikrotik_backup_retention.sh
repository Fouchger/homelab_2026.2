#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/80_mikrotik_backup_retention.sh
# Created: 2026-01-20
# Description: Smoke test for MikroTik backup + retention logic.
# Usage:
#   CONFIRM_MIKROTIK=yes scripts/tests/80_mikrotik_backup_retention.sh
# Notes:
#   - This touches the router. It is gated by CONFIRM_MIKROTIK=yes.
#   - It runs a single backup and verifies that artefacts were written locally.
# Environment:
#   MIKROTIK_BACKUP_KEEP=N (optional override)
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

if [[ "${CONFIRM_MIKROTIK:-no}" != "yes" ]]; then
  error "Refusing to run MikroTik tests without CONFIRM_MIKROTIK=yes"
  exit 1
fi

# Run backup via existing module (includes retention)
info "Running MikroTik backup"
"${REPO_ROOT}/scripts/mikrotik/backup.sh"

# Find latest backup folder
BACKUP_ROOT="${HOME}/.config/homelab_2026_2/backups/mikrotik"
if [[ ! -d "${BACKUP_ROOT}" ]]; then
  error "Backup folder not found: ${BACKUP_ROOT}"
  exit 1
fi

latest_dir="$(find "${BACKUP_ROOT}" -type d -maxdepth 4 -mindepth 2 2>/dev/null | sort | tail -n 1 || true)"
if [[ -z "${latest_dir}" ]]; then
  error "No backup directories found under: ${BACKUP_ROOT}"
  exit 1
fi

info "Latest backup dir: ${latest_dir}"
count_files="$(find "${latest_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${count_files}" -lt 1 ]]; then
  error "No backup files found in: ${latest_dir}"
  exit 1
fi

ok "MikroTik backup smoke test passed (${count_files} files)"
