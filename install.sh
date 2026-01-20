#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: install.sh
# Created: 2026-01-18
# Description: Installer for homelab_2026.2.
# Usage:
#   bash install.sh
# Developer notes:
#   - For unattended installs set HOMELAB_GIT_URL and HOMELAB_DIR.
#   - This script expects a Makefile with targets: bootstrap, menu.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/Fouchger/homelab_2026_2}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

die() {
  echo "Error: $*" >&2
  exit 1
}

if ! need_cmd git; then
  die "git is required. On Debian/Ubuntu: sudo apt-get update -y && sudo apt-get install -y git"
fi

if ! need_cmd make; then
  die "make is required. On Debian/Ubuntu: sudo apt-get update -y && sudo apt-get install -y make"
fi

# Prompt only if interactive
if [ -z "${HOMELAB_GIT_URL}" ]; then
  if [ -t 0 ]; then
    read -r -p "Enter Git URL for homelab_2026.2 (e.g. git@github.com:org/homelab_2026.2.git): " HOMELAB_GIT_URL
  else
    die "HOMELAB_GIT_URL is not set and stdin is not interactive. Set HOMELAB_GIT_URL and re-run."
  fi
fi

[ -n "${HOMELAB_GIT_URL}" ] || die "No Git URL provided."

mkdir -p "$(dirname "${HOMELAB_DIR}")"

if [ -d "${HOMELAB_DIR}/.git" ]; then
  echo "Updating existing repo in ${HOMELAB_DIR}"
  if ! git -C "${HOMELAB_DIR}" pull --ff-only; then
    echo "Your local repo can't fast-forward. Options:" >&2
    echo "  - Commit or stash your changes, then re-run" >&2
    echo "  - Or reset hard to remote if you know what you're doing" >&2
    exit 1
  fi
else
  echo "Cloning repo to ${HOMELAB_DIR}"
  git clone "${HOMELAB_GIT_URL}" "${HOMELAB_DIR}"
fi

cd "${HOMELAB_DIR}"

[ -f "Makefile" ] || die "Makefile not found in ${HOMELAB_DIR}. Is this the right repo?"

if [ -x "scripts/make-executable.sh" ]; then
  ./scripts/make-executable.sh
elif [ -f "scripts/make-executable.sh" ]; then
  bash scripts/make-executable.sh
else
  echo "Note: scripts/make-executable.sh not found; skipping."
fi

make bootstrap
make menu
