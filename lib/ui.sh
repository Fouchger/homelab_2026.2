#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/ui.sh
# Created: 2026-01-18
# Description: Terminal UI helpers (dialog/whiptail + plain fallback).
# Usage:
#   source "${REPO_ROOT}/lib/ui.sh"
#   ui_select "Title" "Prompt" outvar option1 "Label 1" ...
# Developer notes:
#   - Prefer dialog because it supports spacebar selection and multiselect.
#   - Never require a GUI; dialog runs in TTY.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

ui_has_dialog() { command -v dialog >/dev/null 2>&1; }
ui_has_whiptail() { command -v whiptail >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# Dialog execution wrapper
# -----------------------------------------------------------------------------
# Purpose
#   Ensure dialog behaves consistently across environments where stdin may not be
#   a real TTY (for example when launched via make, wrappers, or some web
#   consoles). Arrow keys and checklist navigation rely on ncurses reading from
#   a proper terminal.
#
# Approach
#   - Prefer reading input from /dev/tty when available.
#   - Disable mouse support by default to avoid terminal/client incompatibility.
#   - Fall back to plain dialog invocation if /dev/tty is unavailable.
#
# Notes
#   This mirrors the robust pattern used in the standalone App Manager script.

ui_dialog() {
  # Usage: ui_dialog <dialog args...>
  # Returns dialog exit status.
  local -a args=("$@")

  # Disable mouse unless the caller explicitly opted in.
  # Use DIALOGOPTS so it applies consistently to all dialog widgets.
  if [[ "${DIALOGOPTS:-}" != *"--mouse"* && "${DIALOGOPTS:-}" != *"--no-mouse"* ]]; then
    export DIALOGOPTS="${DIALOGOPTS:-} --no-mouse"
  fi

  # Best-effort TERM normalisation for web/serial consoles.
  export TERM="${TERM:-xterm-256color}"

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    dialog "${args[@]}" </dev/tty
  else
    dialog "${args[@]}"
  fi
}

ui_ensure_ui_deps() {
  if ui_has_dialog || ui_has_whiptail; then
    return 0
  fi

  warn "dialog/whiptail not found. Installing dialog (Debian/Ubuntu only)."
  apt_install dialog || {
    warn "Could not install dialog. Falling back to plain prompts."
    return 0
  }
}

ui_confirm() {
  local title prompt default
  title="$1"; prompt="$2"; default="${3:-no}"
  ui_ensure_ui_deps

  if ui_has_dialog; then
    ui_dialog --clear --title "$title" --yesno "$prompt" 10 70
    return $?
  elif ui_has_whiptail; then
    whiptail --title "$title" --yesno "$prompt" 10 70
    return $?
  else
    local ans
    if [ "$default" = "yes" ]; then
      read -r -p "$prompt (Y/n): " ans
      ans="${ans:-Y}"
    else
      read -r -p "$prompt (y/N): " ans
      ans="${ans:-N}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
  fi
}

ui_input() {
  local title prompt default
  title="$1"; prompt="$2"; default="${3:-}"
  ui_ensure_ui_deps

  if ui_has_dialog; then
    ui_dialog --clear --title "$title" --inputbox "$prompt" 10 80 "$default" 2>"$STATE_DIR_DEFAULT/.ui_input"
    cat "$STATE_DIR_DEFAULT/.ui_input"
  elif ui_has_whiptail; then
    whiptail --title "$title" --inputbox "$prompt" 10 80 "$default" 2>"$STATE_DIR_DEFAULT/.ui_input"
    cat "$STATE_DIR_DEFAULT/.ui_input"
  else
    local ans
    read -r -p "$prompt [$default]: " ans
    printf '%s' "${ans:-$default}"
  fi
}

# Single-select menu: args are key/label pairs.
ui_menu() {
  local title prompt outvar
  title="$1"; prompt="$2"; outvar="$3"; shift 3
  ui_ensure_ui_deps

  if ui_has_dialog; then
    ui_dialog --clear --title "$title" --menu "$prompt" 20 90 12 "$@" 2>"$STATE_DIR_DEFAULT/.ui_menu"
    printf -v "$outvar" '%s' "$(cat "$STATE_DIR_DEFAULT/.ui_menu")"
  elif ui_has_whiptail; then
    whiptail --title "$title" --menu "$prompt" 20 90 12 "$@" 2>"$STATE_DIR_DEFAULT/.ui_menu"
    printf -v "$outvar" '%s' "$(cat "$STATE_DIR_DEFAULT/.ui_menu")"
  else
    warn "Interactive menu not available; plain selection used."
    local i=1 keys=() labels=()
    while [ "$#" -gt 0 ]; do
      keys+=("$1"); labels+=("$2"); shift 2
    done
    for idx in "${!keys[@]}"; do
      printf '%s) %s\n' "$((idx+1))" "${labels[$idx]}"
    done
    read -r -p "Enter choice number: " i
    i=$((i-1))
    printf -v "$outvar" '%s' "${keys[$i]}"
  fi
}

# Multi-select checklist. Expects triplets: key label default(on/off)
ui_checklist() {
  local title prompt outvar
  title="$1"; prompt="$2"; outvar="$3"; shift 3
  ui_ensure_ui_deps

  if ui_has_dialog; then
    ui_dialog --clear --title "$title" --checklist "$prompt" 22 100 14 "$@" 2>"$STATE_DIR_DEFAULT/.ui_check"
    # dialog returns quoted values. Remove quotes.
    local raw; raw="$(cat "$STATE_DIR_DEFAULT/.ui_check" | tr -d '"')"
    printf -v "$outvar" '%s' "$raw"
  else
    warn "Checklist not available; selecting all defaults marked on."
    local selected=()
    while [ "$#" -gt 0 ]; do
      local k="$1" l="$2" d="$3"; shift 3
      if [ "$d" = "on" ]; then selected+=("$k"); fi
    done
    printf -v "$outvar" '%s' "${selected[*]}"
  fi
}
