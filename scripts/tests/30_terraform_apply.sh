#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/30_terraform_apply.sh
# Created: 2026-01-20
# Description: Run terraform apply using existing proxmox wrapper.
# Usage:
#   CONFIRM_APPLY=yes scripts/tests/30_terraform_apply.sh
# Notes:
#   - This WILL change infrastructure. It is gated by CONFIRM_APPLY=yes.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

need_cmd terraform

if [[ "${CONFIRM_APPLY:-no}" != "yes" ]]; then
  error "Refusing to run terraform apply without CONFIRM_APPLY=yes"
  error "Set CONFIRM_APPLY=yes if you really want to apply infrastructure changes."
  exit 1
fi

exec "${REPO_ROOT}/scripts/proxmox/terraform.sh" apply
