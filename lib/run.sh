#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/run.sh
# Created: 2026-01-18
# Description: Run initialisation (log file per run, traps, diagnostics).
# Usage:
#   source "${REPO_ROOT}/lib/run.sh"
#   run_init "component-name"
# Developer notes:
#   - The log capture uses tee. When stdout is redirected, the caller may choose
#     to disable tee by setting HOMELAB_NO_TEE=1.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

RUN_ID=""
RUN_LOG_FILE=""

run_init() {
  local component ts
  component="${1:-run}"
  ensure_dirs

  ts="$(date +%Y%m%d-%H%M%S)"
  RUN_ID="${ts}-${component}"
  RUN_LOG_FILE="${LOG_DIR_DEFAULT}/${RUN_ID}.log"

  # Start log capture.
  if [ -z "${HOMELAB_NO_TEE:-}" ]; then
    exec > >(tee -a "$RUN_LOG_FILE") 2>&1
  else
    exec >>"$RUN_LOG_FILE" 2>&1
  fi

  info "Run started: ${RUN_ID}"
  info "Log file: ${RUN_LOG_FILE}"

  trap 'run_on_error $? $LINENO' ERR
  trap 'run_on_exit' EXIT
}

run_on_error() {
  local code line
  code="$1"; line="$2"
  error "Run failed (exit ${code}) at line ${line}. See log: ${RUN_LOG_FILE}"
}

run_on_exit() {
  local code
  code="$?"
  if [ "$code" -eq 0 ]; then
    ok "Run completed successfully."
  fi
}
