#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/paths.sh
# Created: 2026-01-18
# Description: Standard path resolution helpers for homelab_2026.2.
# Usage:
#   source "${REPO_ROOT}/lib/paths.sh"
# Developer notes:
#   - Keep this file dependency-free so every script can source it early.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Resolve repository root even when called via symlink or outside git.
get_repo_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

  if command -v git >/dev/null 2>&1; then
    if git_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s' "$git_root"
      return 0
    fi
  fi

  # Fallback: assume lib/ is directly under repo root.
  printf '%s' "$(cd -- "$script_dir/.." && pwd -P)"
}

REPO_ROOT="$(get_repo_root)"
STATE_DIR_DEFAULT="${STATE_DIR_DEFAULT:-$HOME/.config/homelab_2026_2}"
LOG_DIR_DEFAULT="${LOG_DIR_DEFAULT:-$STATE_DIR_DEFAULT/logs}"
