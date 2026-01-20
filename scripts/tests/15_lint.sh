#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/15_lint.sh
# Created: 2026-01-20
# Description: Run local quality gates (shellcheck, ansible-lint, terraform fmt).
# Usage:
#   scripts/tests/15_lint.sh
# Notes:
#   - Best-effort: only fails if the underlying lint script fails.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"

exec "${REPO_ROOT}/scripts/core/lint.sh"
