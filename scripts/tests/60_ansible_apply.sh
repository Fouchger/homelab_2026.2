#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/60_ansible_apply.sh
# Created: 2026-01-20
# Description: Run Ansible apply (real changes) against the selected inventory.
# Usage:
#   CONFIRM_APPLY=yes scripts/tests/60_ansible_apply.sh /path/to/hosts.ini
# Notes:
#   - This WILL change systems. It is gated by CONFIRM_APPLY=yes.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

INV="${1:-}"
if [[ -z "${INV}" || ! -f "${INV}" ]]; then
  error "Inventory not available. Refusing to run Ansible apply without a valid inventory."
  exit 1
fi

need_cmd ansible-playbook

if [[ "${CONFIRM_APPLY:-no}" != "yes" ]]; then
  error "Refusing to run Ansible apply without CONFIRM_APPLY=yes"
  error "Set CONFIRM_APPLY=yes if you really want to apply configuration changes."
  exit 1
fi

export INVENTORY_FILE="${INV}"

info "Running Ansible apply"
exec "${REPO_ROOT}/scripts/core/ansible.sh"
