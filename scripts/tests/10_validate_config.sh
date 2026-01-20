#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/10_validate_config.sh
# Created: 2026-01-20
# Description: Validate configuration as the first "real" test gate.
# Usage:
#   scripts/tests/10_validate_config.sh
# Notes:
#   - Respects SKIP_VALIDATE=yes (mirrors main tooling behaviour).
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"

if [[ "${SKIP_VALIDATE:-no}" == "yes" ]]; then
  warn "SKIP_VALIDATE=yes set. Skipping validation gate."
  exit 0
fi

exec "${REPO_ROOT}/scripts/core/validate.sh"
