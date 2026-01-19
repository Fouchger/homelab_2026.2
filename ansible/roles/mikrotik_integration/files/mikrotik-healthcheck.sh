#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: ansible/roles/mikrotik_integration/files/mikrotik-healthcheck.sh
# Created: 2026-01-19
# Updated: 2026-01-19
# Description: Standalone MikroTik health checks for admin01.
# Usage:
#   /opt/homelab/mikrotik/healthcheck.sh
# Developer notes:
#   - Writes a status file to /root/.config/homelab_2026_2/mikrotik/health.status
#   - Alerting is opt-in; local logs always update.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

log_ts() { date -Is; }
log() { printf '%s %s\n' "$(log_ts)" "$*"; }

STATE_ENV="/root/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

# Optional alerting helper (webhook/SMTP). If it is missing, health checks still work.
if [[ -r "/opt/homelab/mikrotik/notify.sh" ]]; then
  # shellcheck disable=SC1091
  source "/opt/homelab/mikrotik/notify.sh"
fi

MT_HOST="${MIKROTIK_HOST:-${LAN_GATEWAY:-192.168.88.1}}"
DNS1="${DNS01_IP:-192.168.88.2}"
DNS2="${DNS02_IP:-192.168.88.3}"
DOMAIN="${LAN_DOMAIN:-home.arpa}"

STATUS_DIR="/root/.config/homelab_2026_2/mikrotik"
STATUS_FILE="${STATUS_DIR}/health.status"
FAIL_TEXT_LOG="${STATUS_DIR}/health.failures.log"
mkdir -p "${STATUS_DIR}"

need() { command -v "$1" >/dev/null 2>&1 || { log "ERROR missing dependency: $1"; exit 1; }; }
need ping
need curl

ok_count=0
fail_count=0
failures=()

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    log "OK ${name}"
    ok_count=$((ok_count + 1))
  else
    log "FAIL ${name}"
    fail_count=$((fail_count + 1))
    failures+=("${name}")
  fi
}

check "ping_mikrotik" ping -c 1 -W 1 "${MT_HOST}"
check "internet_https" curl -fsS --max-time 5 https://1.1.1.1

if command -v dig >/dev/null 2>&1; then
  check "dns01_resolve" dig +time=2 +tries=1 @"${DNS1}" "example.com" A
  check "dns02_resolve" dig +time=2 +tries=1 @"${DNS2}" "example.com" A
else
  log "WARN dig not found (dnsutils). Skipping resolver checks."
fi

{
  echo "timestamp=$(date -Is)"
  echo "mikrotik_host=${MT_HOST}"
  echo "ok=${ok_count}"
  echo "fail=${fail_count}"
} >"${STATUS_FILE}"

if [[ "${fail_count}" -gt 0 ]]; then
  printf '%s %s\n' "$(date -Is)" "Health check failed for ${MT_HOST} (ok=${ok_count} fail=${fail_count}) failures=${failures[*]}" >>"${FAIL_TEXT_LOG}"

  if command -v notify_event >/dev/null 2>&1; then
    notify_event "mikrotik" "ERROR" "MikroTik health check failed" "{\"router\":\"${MT_HOST}\",\"ok\":${ok_count},\"fail\":${fail_count},\"dns01\":\"${DNS1}\",\"dns02\":\"${DNS2}\",\"failures\":[\"$(IFS='\",\"'; echo "${failures[*]}")\"]}"
  fi
  exit 2
fi
