#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/lint.sh
# Created: 2026-01-20
# Description: Lightweight quality gates for homelab_2026.2.
#
# Runs (best-effort):
#   - shellcheck on shell scripts if installed
#   - ansible-lint on the Ansible tree if installed
#   - terraform fmt -check on terraform/ if terraform is installed
#
# Usage:
#   scripts/core/lint.sh
#
# Developer notes:
#   - Keep this friction low. Missing tools emit warnings rather than failing.
#   - This is intentionally not a full CI pipeline, but a practical local check.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"

run_init "lint"

result=0

if command -v shellcheck >/dev/null 2>&1; then
  info "Running shellcheck"
  # Limit to our repo scripts to keep runtime reasonable.
  mapfile -t sh_files < <(
    find "${REPO_ROOT}" -type f \( -name '*.sh' -o -path "${REPO_ROOT}/bin/*" \) | sort
  )
  if ((${#sh_files[@]} > 0)); then
    shellcheck -x "${sh_files[@]}" || result=1
  fi
else
  warn "shellcheck not installed; skipping"
fi

if command -v ansible-lint >/dev/null 2>&1; then
  info "Running ansible-lint"
  ansible-lint "${REPO_ROOT}/ansible" || result=1
else
  warn "ansible-lint not installed; skipping"
fi

if command -v terraform >/dev/null 2>&1; then
  info "Running terraform fmt -check"
  (cd "${REPO_ROOT}/terraform" && terraform fmt -recursive -check) || result=1
else
  warn "terraform not installed; skipping terraform fmt checks"
fi

if [[ "${result}" -eq 0 ]]; then
  ok "Lint checks passed"
else
  warn "Lint checks found issues"
fi

exit "${result}"
