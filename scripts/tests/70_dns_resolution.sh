#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/tests/70_dns_resolution.sh
# Created: 2026-01-20
# Description: DNS resolution checks against dns01 and dns02.
# Usage:
#   scripts/tests/70_dns_resolution.sh [inventory]
# Notes:
#   - Uses DNS01_IP/DNS02_IP from ~/.config/homelab_2026_2/state.env when present.
#   - Requires 'dig' (package: dnsutils).
# Environment:
#   TEST_DNS_NAME=example.com            (default: example.com)
#   TEST_LOCAL_ZONE=home.arpa            (default: home.arpa)
#   TEST_LOCAL_RECORD=dns01.home.arpa    (default: dns01.home.arpa)
#   TEST_TIMEOUT=2                       (default: 2 seconds)
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

need_cmd dig

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

DNS01="${DNS01_IP:-}"
DNS02="${DNS02_IP:-}"

if [[ -z "${DNS01}" || -z "${DNS02}" ]]; then
  warn "DNS01_IP/DNS02_IP not found in state.env. Falling back to defaults."
  DNS01="${DNS01:-192.168.88.2}"
  DNS02="${DNS02:-192.168.88.3}"
fi

TEST_DNS_NAME="${TEST_DNS_NAME:-example.com}"
TEST_LOCAL_ZONE="${TEST_LOCAL_ZONE:-home.arpa}"
TEST_LOCAL_RECORD="${TEST_LOCAL_RECORD:-dns01.${TEST_LOCAL_ZONE}}"
TEST_TIMEOUT="${TEST_TIMEOUT:-2}"

query_server() {
  local server="$1" name="$2"
  # +time and +tries ensure failures return fast in lab networks.
  dig @"${server}" "${name}" +time="${TEST_TIMEOUT}" +tries=1 +short
}

check_external() {
  local server="$1"
  local ans
  info "Querying ${TEST_DNS_NAME} via ${server}"
  ans="$(query_server "${server}" "${TEST_DNS_NAME}" || true)"
  if [[ -n "${ans}" ]]; then
    ok "${server} resolved ${TEST_DNS_NAME}: ${ans//$'\n'/, }"
    return 0
  fi
  error "${server} did not resolve ${TEST_DNS_NAME}"
  return 1
}

check_local_optional() {
  local server="$1"
  local ans
  info "Querying local record ${TEST_LOCAL_RECORD} via ${server} (optional)"
  ans="$(query_server "${server}" "${TEST_LOCAL_RECORD}" || true)"
  if [[ -n "${ans}" ]]; then
    ok "${server} resolved ${TEST_LOCAL_RECORD}: ${ans//$'\n'/, }"
    return 0
  fi
  warn "${server} did not resolve ${TEST_LOCAL_RECORD} (this may be ok if you haven't defined it yet)"
  return 0
}

fail=0
check_external "${DNS01}" || fail=1
check_external "${DNS02}" || fail=1

check_local_optional "${DNS01}" || true
check_local_optional "${DNS02}" || true

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

ok "DNS resolution checks passed"
