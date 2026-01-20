#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/healthcheck.sh
# Created: 2026-01-20
# Description: End-to-end health checks for the homelab control plane.
#
# Checks (safe-by-default):
#   - Reachability: dns01, dns02, and (optionally) MikroTik
#   - DNS resolution: dig against dns01 and dns02
#   - Provider hints: optional HTTP checks for AdGuard/Technitium
#
# Usage:
#   scripts/core/healthcheck.sh
#
# Developer notes:
#   - Designed to run from admin01, but works anywhere with network access.
#   - Emits alert events via scripts/alerts/notify.sh (opt-in channels).
#   - Local logging always occurs.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"
source "${REPO_ROOT}/lib/state.sh"
source "${REPO_ROOT}/scripts/alerts/notify.sh"

run_init "healthcheck"
state_init

need_cmd ping

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

DNS1="${DNS01_IP:-192.168.88.2}"
DNS2="${DNS02_IP:-192.168.88.3}"
MT="${MIKROTIK_HOST:-${LAN_GATEWAY:-192.168.88.1}}"
PROVIDER="${DNS_PROVIDER:-bind9}"

STATUS_DIR="${HOME}/.config/homelab_2026_2/health"
STATUS_FILE="${STATUS_DIR}/health.status"
FAIL_TEXT_LOG="${STATUS_DIR}/health.failures.log"
mkdir -p "${STATUS_DIR}"

result_ok=1
failures=()

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "${label}"
  else
    warn "${label}"
    result_ok=0
    failures+=("${label}")
  fi
}

info "Checking DNS node reachability"
check "ping_dns01" ping -c 1 -W 1 "${DNS1}"
check "ping_dns02" ping -c 1 -W 1 "${DNS2}"

if [[ -n "${MT}" ]]; then
  info "Checking MikroTik reachability (optional)"
  check "ping_mikrotik" ping -c 1 -W 1 "${MT}"
fi

if command -v dig >/dev/null 2>&1; then
  info "Checking DNS resolution"
  check "dns01_example" dig +time=2 +tries=1 @"${DNS1}" example.com A
  check "dns02_example" dig +time=2 +tries=1 @"${DNS2}" example.com A
else
  warn "dig not installed; skipping DNS queries (install dnsutils on this node)"
fi

# Optional provider hints (best-effort)
if command -v curl >/dev/null 2>&1; then
  case "${PROVIDER}" in
    adguard)
      # AdGuard Home web UI is typically :3000 and/or metrics endpoints.
      info "Checking AdGuard Home HTTP (best-effort)"
      check "adguard_dns01_http" curl -fsS --max-time 2 "http://${DNS1}:3000"
      check "adguard_dns02_http" curl -fsS --max-time 2 "http://${DNS2}:3000"
      ;;
    technitium)
      # Technitium DNS Server web console is typically :5380.
      info "Checking Technitium HTTP (best-effort)"
      check "technitium_dns01_http" curl -fsS --max-time 2 "http://${DNS1}:5380"
      check "technitium_dns02_http" curl -fsS --max-time 2 "http://${DNS2}:5380"
      ;;
  esac
fi

if [[ "${result_ok}" -eq 1 ]]; then
  printf 'OK %s\n' "$(date -Is)" >"${STATUS_FILE}"
  ok "Health check OK"
else
  printf 'FAIL %s\n' "$(date -Is)" >"${STATUS_FILE}"
  warn "Health check found issues"

  printf '%s %s\n' "$(date -Is)" "Health check failures=${failures[*]}" >>"${FAIL_TEXT_LOG}"

  notify_event "homelab" "ERROR" "Homelab health check failed" "{\"dns01\":\"${DNS1}\",\"dns02\":\"${DNS2}\",\"provider\":\"${PROVIDER}\",\"failures\":[\"$(IFS='\",\"'; echo "${failures[*]}")\"]}"
  exit 1
fi

exit 0
