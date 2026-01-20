#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/mikrotik/healthcheck.sh
# Created: 2026-01-19
# Updated: 2026-01-19
# Description: Health checks for MikroTik edge and core services.
# Usage:
#   scripts/mikrotik/healthcheck.sh
# Developer notes:
#   - Intended to run on admin01 via systemd timer.
#   - Writes a small status file for menu display.
#   - Alerting is opt-in; local logs always update.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/scripts/alerts/notify.sh"

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
FAIL_TEXT_LOG="${STATUS_DIR}/health.failures.log"
mkdir -p "${STATUS_DIR}"

result_ok=1
failures=()

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "${label}"
  else
    warn "${label}"
    result_ok=0
    failures+=("${label}")
  fi
}

info "Checking MikroTik reachability (${MT_HOST})"
check "ping_mikrotik" ping -c 1 -W 1 "${MT_HOST}"

info "Checking internet egress"
check "internet_https" curl -fsS --max-time 3 https://1.1.1.1

if command -v dig >/dev/null 2>&1; then
  info "Checking DNS resolution against homelab DNS nodes"
  check "dns01_resolve" dig +time=2 +tries=1 @"${DNS1}" "example.com" A
  check "dns02_resolve" dig +time=2 +tries=1 @"${DNS2}" "example.com" A
else
  warn "dig not installed; skipping DNS checks (install dnsutils)"
fi

if [[ "${result_ok}" -eq 1 ]]; then
  printf 'OK %s\n' "$(date -Is)" >"${STATUS_FILE}"
  ok "Health check OK"
else
  printf 'FAIL %s\n' "$(date -Is)" >"${STATUS_FILE}"
  warn "Health check found issues"

  printf '%s %s\n' "$(date -Is)" "Health check failed for ${MT_HOST} failures=${failures[*]}" >>"${FAIL_TEXT_LOG}"

  # Optional alerting: local JSON log always; webhook/SMTP if configured.
  # Throttling is handled by notify.sh.
  notify_event "mikrotik" "ERROR" "MikroTik health check failed" "{\"router\":\"${MT_HOST}\",\"dns01\":\"${DNS1}\",\"dns02\":\"${DNS2}\",\"failures\":[\"$(IFS='\",\"'; echo "${failures[*]}")\"]}"
fi
