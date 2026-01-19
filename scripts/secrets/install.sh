#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/secrets/install.sh
# Created: 2026-01-19
# Description: Install recommended secrets tooling (SOPS, age, rbw) on Debian/Ubuntu.
# Usage:
#   scripts/secrets/install.sh
# Developer notes:
#   - Installs packages only. Vaultwarden itself is deployed by the vaultwarden role.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"
source "${REPO_ROOT}/lib/run.sh"

run_init "secrets_install"

if ! command -v apt-get >/dev/null 2>&1; then
  error "This installer currently supports Debian/Ubuntu (apt-get)."
  exit 1
fi

sudo apt-get update -y
sudo apt-get install -y sops age rbw

ok "Installed: sops, age, rbw"
info "Next steps:"
info "1) Configure rbw: rbw config set base_url <your-vaultwarden-url>"
info "2) Login: rbw login"
info "3) Create item: homelab_2026_2_age_key (password field = AGE private key)"
