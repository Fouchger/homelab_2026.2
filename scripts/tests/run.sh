#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/run.sh
# Created: 2026-01-20
# Description: Orchestrated test runner for homelab_2026.2.
# Usage:
#   scripts/tests/run.sh                 # Safe defaults (no apply by default)
#   scripts/tests/run.sh quick           # Preflight + validate + lint + healthcheck
#   scripts/tests/run.sh infra           # Includes terraform plan (no apply)
#   scripts/tests/run.sh apply           # Runs terraform apply + ansible apply + full checks (DANGEROUS)
#   scripts/tests/run.sh --help
#
# Test philosophy:
#   - Default is safe and read-only where possible.
#   - Potentially destructive actions are opt-in via mode or env flags.
#   - Every phase writes logs under: ~/.config/homelab_2026_2/logs/tests/
#
# Configuration (env vars):
#   RUN_TERRAFORM_PLAN=yes|no        Default: yes for mode=infra/apply, else no
#   RUN_TERRAFORM_APPLY=yes|no       Default: yes only for mode=apply
#   RUN_ANSIBLE_CHECK=yes|no         Default: yes when inventory exists
#   RUN_ANSIBLE_APPLY=yes|no         Default: yes only for mode=apply
#   RUN_MIKROTIK_TESTS=yes|no        Default: no
#   TARGET_INVENTORY=path            Default: inventories/proxmox/hosts.ini (if present)
#   TEST_DNS_NAME=example.com        Default: example.com
#   TEST_LOCAL_ZONE=home.arpa        Default: home.arpa
#   TEST_LOCAL_RECORD=dns01.home.arpa Default: dns01.home.arpa
#
# Developer notes:
#   - Keep this bash-only and dependency-light.
#   - Use existing logging + state conventions.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"

run_init "tests"
state_init
ensure_dirs

help() {
  cat <<'USAGE'
Homelab test runner

Usage:
  scripts/tests/run.sh [quick|infra|apply]

Modes:
  quick  Safe local checks: preflight, validate, lint, healthcheck
  infra  Adds terraform plan and inventory checks (no apply)
  apply  Runs terraform apply + ansible apply + full verification (DANGEROUS)

Exit codes:
  0  All selected tests passed
  1  One or more tests failed
  2  Usage error

Tip:
  You can also run: bin/homelab test [mode]
USAGE
}

MODE="${1:-quick}"
if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
  help
  exit 0
fi

case "${MODE}" in
  quick|infra|apply) : ;;
  *)
    error "Unknown mode: ${MODE}"
    help
    exit 2
    ;;
esac

# Defaults by mode (can be overridden by env)
RUN_TERRAFORM_PLAN="${RUN_TERRAFORM_PLAN:-no}"
RUN_TERRAFORM_APPLY="${RUN_TERRAFORM_APPLY:-no}"
RUN_ANSIBLE_CHECK="${RUN_ANSIBLE_CHECK:-yes}"
RUN_ANSIBLE_APPLY="${RUN_ANSIBLE_APPLY:-no}"
RUN_MIKROTIK_TESTS="${RUN_MIKROTIK_TESTS:-no}"

if [[ "${MODE}" == "infra" ]]; then
  RUN_TERRAFORM_PLAN="${RUN_TERRAFORM_PLAN:-yes}"
fi
if [[ "${MODE}" == "apply" ]]; then
  RUN_TERRAFORM_PLAN="${RUN_TERRAFORM_PLAN:-yes}"
  RUN_TERRAFORM_APPLY="${RUN_TERRAFORM_APPLY:-yes}"
  RUN_ANSIBLE_APPLY="${RUN_ANSIBLE_APPLY:-yes}"
fi

TARGET_INVENTORY="${TARGET_INVENTORY:-}"
if [[ -z "${TARGET_INVENTORY}" ]]; then
  if [[ -f "${REPO_ROOT}/inventories/proxmox/hosts.ini" ]]; then
    TARGET_INVENTORY="${REPO_ROOT}/inventories/proxmox/hosts.ini"
  elif [[ -f "${REPO_ROOT}/inventories/hosts.ini" ]]; then
    TARGET_INVENTORY="${REPO_ROOT}/inventories/hosts.ini"
  else
    TARGET_INVENTORY=""
  fi
fi

TEST_RUN_ID="$(date +%Y%m%d_%H%M%S)"
TEST_LOG_DIR="${LOG_DIR_DEFAULT}/tests/${TEST_RUN_ID}"
mkdir -p "${TEST_LOG_DIR}"

info "Test mode: ${MODE}"
info "Logs: ${TEST_LOG_DIR}"

fail_count=0

run_phase() {
  local name="$1"; shift
  local script="$1"; shift
  local log_file="${TEST_LOG_DIR}/${name}.log"

  info "Running: ${name}"
  if "${script}" "$@" 2>&1 | tee "${log_file}"; then
    ok "PASS: ${name}"
  else
    error "FAIL: ${name} (see ${log_file})"
    fail_count=$((fail_count+1))
  fi
}

# Phase ordering is intentional: local -> infra -> config -> live checks
run_phase "00_preflight_local" "${REPO_ROOT}/scripts/tests/00_preflight_local.sh"
run_phase "10_validate_config" "${REPO_ROOT}/scripts/tests/10_validate_config.sh"
run_phase "15_lint" "${REPO_ROOT}/scripts/tests/15_lint.sh"

if [[ "${RUN_TERRAFORM_PLAN}" == "yes" ]]; then
  run_phase "20_terraform_plan" "${REPO_ROOT}/scripts/tests/20_terraform_plan.sh"
fi

if [[ "${RUN_TERRAFORM_APPLY}" == "yes" ]]; then
  run_phase "30_terraform_apply" "${REPO_ROOT}/scripts/tests/30_terraform_apply.sh"
fi

run_phase "40_inventory_check" "${REPO_ROOT}/scripts/tests/40_inventory_check.sh" "${TARGET_INVENTORY}"

if [[ "${RUN_ANSIBLE_CHECK}" == "yes" ]]; then
  run_phase "50_ansible_check" "${REPO_ROOT}/scripts/tests/50_ansible_check.sh" "${TARGET_INVENTORY}"
fi

if [[ "${RUN_ANSIBLE_APPLY}" == "yes" ]]; then
  run_phase "60_ansible_apply" "${REPO_ROOT}/scripts/tests/60_ansible_apply.sh" "${TARGET_INVENTORY}"
fi

run_phase "70_dns_resolution" "${REPO_ROOT}/scripts/tests/70_dns_resolution.sh" "${TARGET_INVENTORY}"

if [[ "${RUN_MIKROTIK_TESTS}" == "yes" ]]; then
  run_phase "80_mikrotik_backup_retention" "${REPO_ROOT}/scripts/tests/80_mikrotik_backup_retention.sh"
fi

run_phase "90_security_smoke" "${REPO_ROOT}/scripts/tests/90_security_smoke.sh"

if [[ "${fail_count}" -gt 0 ]]; then
  error "Tests completed with failures: ${fail_count}"
  exit 1
fi

ok "All selected tests passed"
exit 0
