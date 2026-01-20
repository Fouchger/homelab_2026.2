#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/secrets/runtime.sh
# Created: 2026-01-19
# Description: Runtime secrets wiring for Ansible using Vaultwarden + SOPS.
# Usage:
#   source scripts/secrets/runtime.sh
# Developer notes:
#   - This script is sourced by scripts/core/ansible.sh.
#   - Secrets are never written to the git working tree. Decrypted material is
#     written to a per-run temp directory and cleaned up on exit.
#   - Vaultwarden is Bitwarden-compatible. We use the rbw CLI (recommended on
#     Ubuntu) to fetch the AGE private key at runtime.
#   - Convention: store an item named "homelab_2026_2_age_key" where the item
#     password field contains the AGE private key.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# This file is meant to be sourced. Do not execute directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "This script must be sourced, not executed." >&2
  exit 1
fi

source "${REPO_ROOT}/lib/logging.sh"
source "${REPO_ROOT}/lib/core.sh"

STATE_ENV="${HOME}/.config/homelab_2026_2/state.env"
# shellcheck disable=SC1090
[[ -r "${STATE_ENV}" ]] && source "${STATE_ENV}" || true

SECRETS_MODE="${SECRETS_MODE:-vaultwarden_sops}"

# Outputs for the caller (ansible.sh)
ANSIBLE_SECRETS_ARGS=()

if [[ "${SECRETS_MODE}" == "none" ]]; then
  info "Secrets mode: none"
  return 0
fi

need_cmd mktemp

TMP_DIR="$(mktemp -d -t homelab_secrets.XXXXXX)"
cleanup_tmp() { rm -rf "${TMP_DIR}" || true; }
trap cleanup_tmp RETURN

SECRETS_FILE_SRC="${REPO_ROOT}/ansible/group_vars/all/secrets.sops.yaml"
SECRETS_FILE_PLAIN="${TMP_DIR}/secrets.yaml"

# 1) Ensure we have a SOPS age key in-memory.
if [[ -z "${SOPS_AGE_KEY:-}" && "${SECRETS_MODE}" == *"vaultwarden"* ]]; then
  if command -v rbw >/dev/null 2>&1; then
    info "Fetching AGE key from Vaultwarden via rbw"
    info "If this is your first time: run 'rbw config set base_url <your-url>' then 'rbw login'"

    # rbw will prompt interactively for master password if required.
    # We intentionally do not log the secret.
    if AGE_KEY_RAW="$(rbw get "homelab_2026_2_age_key" 2>/dev/null)"; then
      export SOPS_AGE_KEY="${AGE_KEY_RAW}"
      ok "Loaded SOPS_AGE_KEY from Vaultwarden"
    else
      warn "Could not retrieve 'homelab_2026_2_age_key' via rbw."
      warn "You can still proceed by exporting SOPS_AGE_KEY in your shell."
    fi
  else
    warn "rbw is not installed. Install it on your admin node to fetch secrets from Vaultwarden."
  fi
fi

# 2) Decrypt (or pass through) secrets.sops.yaml
if [[ -r "${SECRETS_FILE_SRC}" ]]; then
  if grep -q "^sops:" "${SECRETS_FILE_SRC}"; then
    if command -v sops >/dev/null 2>&1; then
      info "Decrypting secrets via sops"
      sops -d "${SECRETS_FILE_SRC}" >"${SECRETS_FILE_PLAIN}"
      ANSIBLE_SECRETS_ARGS+=("-e" "@${SECRETS_FILE_PLAIN}")
      ok "Secrets injected into Ansible runtime"
    else
      warn "sops not installed; cannot decrypt ${SECRETS_FILE_SRC}"
    fi
  else
    # Not encrypted yet, treat as plain vars file.
    info "Using plain secrets file (not SOPS-encrypted yet)"
    ANSIBLE_SECRETS_ARGS+=("-e" "@${SECRETS_FILE_SRC}")
  fi
else
  warn "No secrets file found at ${SECRETS_FILE_SRC}. Continuing without secret vars."
fi
