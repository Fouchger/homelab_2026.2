#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/validate.sh
# Created: 2026-01-20
# Description: Validate homelab_2026.2 configuration and basic prerequisites.
#
# Usage:
#   scripts/core/validate.sh
#
# Exit codes:
#   0  Valid (or only warnings)
#   2  Validation failures that should block apply
#
# Developer notes:
#   - Safe-by-default. Only fails on clear configuration errors.
#   - Does not require jq. Prefers simple regex checks.
#   - Reads ~/.config/homelab_2026_2/state.env if present.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck source=lib/paths.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
# shellcheck source=lib/logging.sh
source "${REPO_ROOT}/lib/logging.sh"
# shellcheck source=lib/core.sh
source "${REPO_ROOT}/lib/core.sh"
# shellcheck source=lib/run.sh
source "${REPO_ROOT}/lib/run.sh"
# shellcheck source=lib/state.sh
source "${REPO_ROOT}/lib/state.sh"

run_init "validate"
state_init

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

failures=0

is_ipv4() {
  local ip="$1"
  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<<"${ip}"
  for o in "$a" "$b" "$c" "$d"; do
    [[ "${o}" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

is_cidr() {
  local cidr="$1" ip mask
  [[ "${cidr}" == */* ]] || return 1
  ip="${cidr%/*}"
  mask="${cidr#*/}"
  is_ipv4 "${ip}" || return 1
  [[ "${mask}" =~ ^[0-9]+$ ]] || return 1
  (( mask >= 0 && mask <= 32 )) || return 1
  return 0
}

require_nonempty() {
  local name="$1" value="$2"
  if [[ -z "${value}" ]]; then
    error "Missing required setting: ${name}"
    failures=$((failures + 1))
  fi
}

warn_if_empty() {
  local name="$1" value="$2" hint="$3"
  if [[ -z "${value}" ]]; then
    warn "Optional setting not set: ${name}. ${hint}"
  fi
}

validate_enum() {
  local name="$1" value="$2" allowed="$3"
  if [[ -z "${value}" ]]; then
    return 0
  fi
  if ! [[ " ${allowed} " == *" ${value} "* ]]; then
    error "Invalid ${name}: '${value}'. Allowed: ${allowed}"
    failures=$((failures + 1))
  fi
}

info "Validating homelab configuration"

# Network
LAN_CIDR_VAL="${LAN_CIDR:-192.168.88.0/24}"
LAN_GATEWAY_VAL="${LAN_GATEWAY:-192.168.88.1}"
LAN_DOMAIN_VAL="${LAN_DOMAIN:-home.arpa}"

if ! is_cidr "${LAN_CIDR_VAL}"; then
  error "LAN_CIDR is not valid CIDR: ${LAN_CIDR_VAL}"
  failures=$((failures + 1))
fi

if ! is_ipv4 "${LAN_GATEWAY_VAL}"; then
  error "LAN_GATEWAY is not a valid IPv4 address: ${LAN_GATEWAY_VAL}"
  failures=$((failures + 1))
fi

require_nonempty "LAN_DOMAIN" "${LAN_DOMAIN_VAL}"

# DNS provider
DNS_PROVIDER_VAL="${DNS_PROVIDER:-bind9}"
validate_enum "DNS_PROVIDER" "${DNS_PROVIDER_VAL}" "bind9 adguard coredns technitium"

DNS01_IP_VAL="${DNS01_IP:-192.168.88.2}"
DNS02_IP_VAL="${DNS02_IP:-192.168.88.3}"
if ! is_ipv4 "${DNS01_IP_VAL}"; then
  error "DNS01_IP is not a valid IPv4 address: ${DNS01_IP_VAL}"
  failures=$((failures + 1))
fi
if ! is_ipv4 "${DNS02_IP_VAL}"; then
  error "DNS02_IP is not a valid IPv4 address: ${DNS02_IP_VAL}"
  failures=$((failures + 1))
fi

if [[ "${DNS01_IP_VAL}" == "${DNS02_IP_VAL}" ]]; then
  error "DNS01_IP and DNS02_IP must be different"
  failures=$((failures + 1))
fi

# DHCP mode
DHCP_MODE_VAL="${DHCP_MODE:-mikrotik}"
validate_enum "DHCP_MODE" "${DHCP_MODE_VAL}" "mikrotik proxmox"

# Proxmox basics (only hard-required for Terraform actions)
warn_if_empty "PROXMOX_HOST" "${PROXMOX_HOST:-}" "Set it via Settings and questionnaires."
warn_if_empty "PROXMOX_NODE" "${PROXMOX_NODE:-}" "Default is pve01."

# MikroTik integration is optional
if [[ -n "${MIKROTIK_HOST:-}" ]]; then
  if ! is_ipv4 "${MIKROTIK_HOST}"; then
    warn "MIKROTIK_HOST doesn't look like an IPv4 address: ${MIKROTIK_HOST} (DNS names are also fine if resolvable)"
  fi
fi

if [[ -n "${MIKROTIK_SSH_KEY_PATH:-}" ]] && [[ ! -r "${MIKROTIK_SSH_KEY_PATH}" ]]; then
  warn "MIKROTIK_SSH_KEY_PATH not readable: ${MIKROTIK_SSH_KEY_PATH}"
fi

# Services selection
SERVICES_VAL="${DESIRED_SERVICES:-admin dns}"
if [[ -z "${SERVICES_VAL}" ]]; then
  warn "DESIRED_SERVICES not set; defaulting to: admin dns"
fi

ok "Validation complete"

if (( failures > 0 )); then
  error "Validation failed with ${failures} issue(s). Fix settings via the questionnaires and re-run."
  exit 2
fi

exit 0
