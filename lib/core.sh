#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/core.sh
# Created: 2026-01-18
# Description: Core helpers shared across scripts (deps, sudo, OS checks).
# Usage:
#   source "${REPO_ROOT}/lib/paths.sh"
#   source "${REPO_ROOT}/lib/logging.sh"
#   source "${REPO_ROOT}/lib/core.sh"
# Developer notes:
#   - Keep bash 4+ compatible.
#   - Avoid non-POSIX flags.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Missing required command: $1"
    return 1
  }
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

require_sudo() {
  if is_root; then
    return 0
  fi
  if ! have_cmd sudo; then
    error "sudo is required but not installed. Install sudo or run as root."
    return 1
  fi
  sudo -v
}

get_os_id() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s' "${ID:-unknown}"
  else
    printf '%s' "unknown"
  fi
}

get_os_like() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s' "${ID_LIKE:-}"
  else
    printf '%s' ""
  fi
}

is_debian_like() {
  local id like
  id="$(get_os_id)"; like="$(get_os_like)"
  case "$id" in debian|ubuntu|raspbian) return 0 ;; esac
  printf '%s' "$like" | grep -qiE '(debian|ubuntu)' && return 0
  return 1
}

apt_install() {
  local pkgs
  pkgs=("$@")
  require_sudo
  if ! is_debian_like; then
    warn "apt_install called on non-Debian system. Skipping: ${pkgs[*]}"
    return 0
  fi
  info "Installing packages: ${pkgs[*]}"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
}

ensure_dirs() {
  mkdir -p "$LOG_DIR_DEFAULT" "$STATE_DIR_DEFAULT"
}
