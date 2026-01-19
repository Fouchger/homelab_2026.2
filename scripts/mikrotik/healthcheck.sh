#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/healthcheck.sh
# Created: 2026-01-19
# Description: Health checks for MikroTik edge and core services.
# Usage:
#   scripts/mikrotik/healthcheck.sh
# Developer notes:
#   - Intended to run on admin01 via systemd timer.
#   - Writes a small status file for menu display.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"

run_init "mikrotik_healthcheck"
state_init

need_cmd ping
need_cmd curl

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

MT_HOST="${MIKROTIK_HOST:-${LAN_GATEWAY:-192.168.88.1}}"
DNS1="${DNS01_IP:-192.168.88.2}"
DNS2="${DNS02_IP:-192.168.88.3}"
DOMAIN="${LAN_DOMAIN:-home.arpa}"

STATUS_DIR="${HOME}/.config/homelab_2026_2/mikrotik"
STATUS_FILE="${STATUS_DIR}/health.status"
mkdir -p "${STATUS_DIR}"

result_ok=1

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "${label}";
  else
    warn "${label}";
    result_ok=0
  fi
}

info "Checking MikroTik reachability (${MT_HOST})"
check "MikroTik ping" ping -c 1 -W 1 "${MT_HOST}"

info "Checking internet egress"
check "HTTPS to 1.1.1.1" curl -fsS --max-time 3 https://1.1.1.1

if command -v dig >/dev/null 2>&1; then
  info "Checking DNS resolution against homelab DNS nodes"
  check "DNS via dns01" dig +time=2 +tries=1 @"${DNS1}" "example.com" A
  check "DNS via dns02" dig +time=2 +tries=1 @"${DNS2}" "example.com" A
else
  warn "dig not installed; skipping DNS checks (install dnsutils)"
fi

if [[ "${result_ok}" -eq 1 ]]; then
  printf 'OK %s\n' "$(date -Is)" >"${STATUS_FILE}"
  ok "Health check OK"
else
  printf 'FAIL %s\n' "$(date -Is)" >"${STATUS_FILE}"
  warn "Health check found issues"
fi
