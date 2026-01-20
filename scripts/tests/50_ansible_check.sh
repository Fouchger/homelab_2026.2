#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/50_ansible_check.sh
# Created: 2026-01-20
# Description: Run Ansible in check mode (dry-run) against the selected inventory.
# Usage:
#   scripts/tests/50_ansible_check.sh /path/to/hosts.ini
# Notes:
#   - Safe-by-default: uses --check --diff.
#   - Skips if inventory is missing.
# Environment:
#   PLAYBOOK=path/to/playbook.yml (optional)
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

INV="${1:-}"
if [[ -z "${INV}" || ! -f "${INV}" ]]; then
  warn "Inventory not available. Skipping Ansible check mode."
  exit 0
fi

need_cmd ansible-playbook

export INVENTORY_FILE="${INV}"

info "Running Ansible in check mode"
exec "${REPO_ROOT}/scripts/core/ansible.sh" --check --diff
