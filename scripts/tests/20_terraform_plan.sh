#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/20_terraform_plan.sh
# Created: 2026-01-20
# Description: Run terraform plan using existing proxmox wrapper.
# Usage:
#   scripts/tests/20_terraform_plan.sh
# Notes:
#   - This should be safe (no infrastructure changes).
#   - Requires terraform and valid Proxmox credentials.
# Environment:
#   TF_VAR_* and PROXMOX_* variables are respected by the wrapper.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

need_cmd terraform

exec "${REPO_ROOT}/scripts/proxmox/terraform.sh" plan
