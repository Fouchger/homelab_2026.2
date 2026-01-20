#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/40_inventory_check.sh
# Created: 2026-01-20
# Description: Sanity checks for the generated/selected Ansible inventory.
# Usage:
#   scripts/tests/40_inventory_check.sh /path/to/hosts.ini
# Notes:
#   - This is a lightweight gate. It doesn't validate connectivity.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"

INV="${1:-}"
if [[ -z "${INV}" ]]; then
  warn "No inventory path provided. Skipping inventory checks."
  exit 0
fi

if [[ ! -f "${INV}" ]]; then
  error "Inventory not found: ${INV}"
  exit 1
fi

info "Inventory: ${INV}"

# Basic expected hosts. We do not enforce group structure because users may customise.
required=("admin01" "dns01" "dns02")
for h in "${required[@]}"; do
  if grep -qE "^${h}([[:space:]]|$)" "${INV}"; then
    ok "Found host: ${h}"
  else
    warn "Host not found (may be ok if you renamed): ${h}"
  fi
done

# Quick check for obvious mistakes
if grep -qE "^\s*\[" "${INV}"; then
  ok "Inventory contains group headers"
else
  warn "No group headers found. Inventory may still work, but check formatting."
fi

ok "Inventory sanity checks complete"
