#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/00_preflight_local.sh
# Created: 2026-01-20
# Description: Local preflight checks for running homelab_2026.2.
# Usage:
#   scripts/tests/00_preflight_local.sh
# Notes:
#   - This does not touch remote systems.
#   - It checks that the repo is sane and key tools are available.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

ok_count=0

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "${name}"
    ok_count=$((ok_count+1))
  else
    error "${name}"
    return 1
  fi
}

info "Repo root: ${REPO_ROOT}"
check "install.sh exists" test -f "${REPO_ROOT}/install.sh"
check "bin/homelab exists" test -f "${REPO_ROOT}/bin/homelab"
check "scripts/core exists" test -d "${REPO_ROOT}/scripts/core"
check "ansible folder exists" test -d "${REPO_ROOT}/ansible"
check "terraform folder exists" test -d "${REPO_ROOT}/terraform"

# Basic tools (best effort, only fail on hard requirements)
check "bash available" bash -lc 'true'
check "ssh available" command -v ssh
check "git available" command -v git

# Optional tools (warn only)
if have_cmd jq; then ok "jq available"; else warn "jq not found (recommended)"; fi
if have_cmd yq; then ok "yq available"; else warn "yq not found (recommended)"; fi
if have_cmd ansible-playbook; then ok "ansible available"; else warn "ansible not found (required for config phase)"; fi
if have_cmd terraform; then ok "terraform available"; else warn "terraform not found (required for infra phase)"; fi
if have_cmd dig; then ok "dig available"; else warn "dig not found (recommended for DNS tests). Package: dnsutils"; fi

ok "Preflight complete (${ok_count} checks passed)"
