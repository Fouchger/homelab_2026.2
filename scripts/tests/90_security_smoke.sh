#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/90_security_smoke.sh
# Created: 2026-01-20
# Description: Basic security and hygiene checks.
# Usage:
#   scripts/tests/90_security_smoke.sh
# Notes:
#   - This is not a full security audit. It checks common foot-guns.
# Checks:
#   - Ensure state.env isn't world-readable (0600 recommended).
#   - Scan repo for obvious secret files that shouldn't be committed.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"

fail=0

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
if [[ -f "${STATE_ENV}" ]]; then
  perm="$(stat -c '%a' "${STATE_ENV}" 2>/dev/null || echo '')"
  if [[ "${perm}" == "600" || "${perm}" == "400" ]]; then
    ok "state.env permissions look ok (${perm})"
  else
    warn "state.env permissions are ${perm}. Recommended: 600"
  fi
else
  warn "state.env not found (ok if you haven't run questionnaires yet)"
fi

# Look for commonly-accidental secret commits
patterns=(
  "*.pem" "*.key" "id_rsa" "id_ed25519" ".env" "*.pfx" "*.p12"
)

for p in "${patterns[@]}"; do
  # Exclude vendor caches and terraform state by design
  if find "${REPO_ROOT}" -path "${REPO_ROOT}/.git" -prune -o -path "${REPO_ROOT}/terraform/.terraform" -prune -o -path "${REPO_ROOT}/terraform/*.tfstate*" -prune -o -name "${p}" -print | grep -q .; then
    warn "Found potential secret file(s) matching: ${p}"
  fi
done

# Quick grep for high-risk keywords in repo (best-effort)
if grep -RIn --exclude-dir=.git --exclude-dir=terraform/.terraform --exclude='*.tfstate*' -E "(PROXMOX_API_TOKEN|VAULTWARDEN|PASSWORD=|SECRET=|BEGIN (RSA|OPENSSH) PRIVATE KEY)" "${REPO_ROOT}" >/dev/null 2>&1; then
  warn "Repo contains one or more high-risk keywords. Review before sharing."
else
  ok "No obvious high-risk keywords found in repo"
fi

# Backups folder permissions (if present)
BACKUP_DIR="${HOME}/.config/homelab_2026_2/backups"
if [[ -d "${BACKUP_DIR}" ]]; then
  perm_b="$(stat -c '%a' "${BACKUP_DIR}" 2>/dev/null || echo '')"
  if [[ -n "${perm_b}" && "${perm_b}" -le 700 ]]; then
    ok "Backups directory permissions look ok (${perm_b})"
  else
    warn "Backups directory permissions are ${perm_b}. Recommended: 700"
  fi
else
  info "Backups directory not present (ok)"
fi

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

ok "Security smoke checks complete"
