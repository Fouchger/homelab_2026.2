#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: install.sh
# Created: 2026-01-18
# Description: Installer for homelab_2026.2.
# Usage:
#   bash install.sh
# Developer notes:
#   - For unattended installs set HOMELAB_GIT_URL and HOMELAB_DIR.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/.local/share/homelab_2026_2/repo}"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd git; then
  echo "git is required. On Debian/Ubuntu: sudo apt-get update -y && sudo apt-get install -y git"
  exit 1
fi

if [ -z "${HOMELAB_GIT_URL}" ]; then
  read -r -p "Enter Git URL for homelab_2026.2 (e.g. git@github.com:org/homelab_2026.2.git): " HOMELAB_GIT_URL
fi

if [ -z "${HOMELAB_GIT_URL}" ]; then
  echo "No Git URL provided. Exiting."
  exit 1
fi

mkdir -p "$(dirname "${HOMELAB_DIR}")"

if [ -d "${HOMELAB_DIR}/.git" ]; then
  echo "Updating existing repo in ${HOMELAB_DIR}"
  git -C "${HOMELAB_DIR}" pull --ff-only
else
  echo "Cloning repo to ${HOMELAB_DIR}"
  git clone "${HOMELAB_GIT_URL}" "${HOMELAB_DIR}"
fi

cd "${HOMELAB_DIR}"
make bootstrap
make menu
