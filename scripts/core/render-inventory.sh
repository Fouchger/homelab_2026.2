#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/render-inventory.sh
# Created: 2026-01-18
# Description: Generate Ansible inventory from Terraform outputs.
# Usage:
#   scripts/core/render-inventory.sh
# Developer notes:
# - Writes inventories/generated.yml and does not overwrite manual inventories.
# - Requires terraform outputs to be present (run after terraform apply).
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"

run_init "render-inventory"

need_cmd terraform
need_cmd jq

TF_DIR="${REPO_ROOT}/terraform"
OUT_FILE="${REPO_ROOT}/inventories/generated.yml"

if [[ ! -d "${TF_DIR}" ]]; then
  error "Terraform directory not found: ${TF_DIR}"
  exit 1
fi

pushd "${TF_DIR}" >/dev/null

admin_json=$(terraform output -json admin || echo 'null')
dns_json=$(terraform output -json dns || echo '{}')

admin_ip=$(jq -r 'if .==null then "" else .ipv4 end' <<<"${admin_json}")

# Build YAML safely.
{
  echo "---"
  echo "# -----------------------------------------------------------------------------"
  echo "# File: inventories/generated.yml"
  echo "# Created: $(date -Iseconds)"
  echo "# Description: Generated inventory from Terraform outputs. Do not edit by hand."
  echo "# -----------------------------------------------------------------------------"
  echo
  echo "all:"
  echo "  vars:"
  echo "    ansible_user: root"
  echo "  children:"
  echo "    admin:"
  echo "      hosts:"
  if [[ -n "${admin_ip}" ]]; then
    echo "        admin01:"
    echo "          ansible_host: ${admin_ip}"
  else
    echo "        {}"
  fi
  echo "    dns:"
  echo "      hosts:"
  if jq -e 'length > 0' <<<"${dns_json}" >/dev/null 2>&1; then
    jq -r 'to_entries[] | "        \(.key):\n          ansible_host: \(.value)"' <<<"${dns_json}"
  else
    echo "        {}"
  fi
  echo "    dhcp:"
  echo "      hosts: {}"
} >"${OUT_FILE}"

popd >/dev/null

success "Generated inventory: ${OUT_FILE}"
