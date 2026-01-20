#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/state.sh
# Created: 2026-01-18
# Description: Lightweight state store for homelab_2026.2.
# Usage:
#   source "${REPO_ROOT}/lib/state.sh"
#   state_set key value
#   state_get key [default]
# Developer notes:
#   - Uses a simple dotenv-style file to avoid hard dependencies on jq.
#   - Keys are normalised to uppercase with underscores.
# ----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

STATE_FILE="${STATE_FILE:-$STATE_DIR_DEFAULT/state.env}"

_state_key() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_'
}

state_init() {
  ensure_dirs
  if [ ! -f "$STATE_FILE" ]; then
    printf '# homelab_2026.2 state\n' >"$STATE_FILE"
    chmod 600 "$STATE_FILE" || true
  fi
}

state_set() {
  local key value nkey
  key="$1"; value="$2"
  nkey="$(_state_key "$key")"
  state_init

  if grep -qE "^${nkey}=" "$STATE_FILE"; then
    # Portable in-place edit.
    tmpfile="${STATE_FILE}.tmp"
    awk -v k="$nkey" -v v="$value" 'BEGIN{FS=OFS="="} {if($1==k){$2=v} print}' "$STATE_FILE" >"$tmpfile"
    mv "$tmpfile" "$STATE_FILE"
  else
    printf '%s=%s\n' "$nkey" "$value" >>"$STATE_FILE"
  fi
}

state_get() {
  local key def nkey
  key="$1"; def="${2:-}"
  nkey="$(_state_key "$key")"
  state_init

  value="$(grep -E "^${nkey}=" "$STATE_FILE" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
  if [ -z "${value:-}" ]; then
    printf '%s' "$def"
  else
    printf '%s' "$value"
  fi
}
