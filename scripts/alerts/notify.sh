#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/alerts/notify.sh
# Created: 2026-01-19
# Updated: 2026-01-19
# Description: Opt-in alerting helper for homelab_2026.2.
#
# Usage:
#   source "${REPO_ROOT}/scripts/alerts/notify.sh"
#   notify_event "mikrotik" "ERROR" "Health check failed" '{"failures":["dns01"]}'
#
# Alert payload schema:
#   - schema: homelab.alert
#   - schema_version: 1.0
#
# Developer notes:
#   - Always appends an alert line to a local JSONL log.
#   - Optional channels (opt-in):
#       * Webhook: set ALERT_WEBHOOK_URL (expects JSON POST)
#       * SMTP: set ALERT_SMTP_TO and ensure sendmail is available (msmtp works)
#   - Throttling (to reduce spam):
#       * ALERT_THROTTLE_SECONDS (default: 900)
#       * ALERT_THROTTLE_KEY_MODE: component | component_severity (default)
#     Throttling only affects webhook/SMTP delivery. Local logging always happens.
#   - Do not store credentials in Git or in state.env. If SMTP auth is needed,
#     fetch the password at runtime using Vaultwarden + SOPS, then export it
#     into the environment (msmtp can reference it).
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

_epoch() { date +%s; }

_throttle_key() {
  local component="$1" severity="$2"
  case "${ALERT_THROTTLE_KEY_MODE:-component_severity}" in
    component) printf '%s' "${component}" ;;
    *) printf '%s|%s' "${component}" "${severity}" ;;
  esac
}

_throttle_should_send() {
  local component="$1" severity="$2"
  local throttle_seconds key dir file now last

  throttle_seconds="${ALERT_THROTTLE_SECONDS:-900}"
  # 0 disables throttling
  if [[ "${throttle_seconds}" =~ ^[0-9]+$ ]] && [[ "${throttle_seconds}" -eq 0 ]]; then
    return 0
  fi

  # If invalid, fall back safely
  if ! [[ "${throttle_seconds}" =~ ^[0-9]+$ ]]; then
    throttle_seconds=900
  fi

  dir="${HOME}/.config/homelab_2026_2/alerts/.throttle"
  mkdir -p "${dir}"

  key="$(_throttle_key "${component}" "${severity}")"
  file="${dir}/$(printf '%s' "${key}" | tr ' /' '__').ts"

  now="$(_epoch)"
  last=0
  if [[ -r "${file}" ]]; then
    last="$(cat "${file}" 2>/dev/null || echo 0)"
    [[ "${last}" =~ ^[0-9]+$ ]] || last=0
  fi

  if (( now - last < throttle_seconds )); then
    return 1
  fi

  printf '%s' "${now}" >"${file}" 2>/dev/null || true
  return 0
}

notify_event() {
  local component severity message details_json
  component="$1"; severity="$2"; message="$3"; details_json="${4:-}"

  local state_env
  state_env="${HOME}/.config/homelab_2026_2/state.env"
  # shellcheck disable=SC1090
  [[ -r "${state_env}" ]] && source "${state_env}" || true

  local alert_dir alert_log ts hostname
  alert_dir="${HOME}/.config/homelab_2026_2/alerts"
  alert_log="${alert_dir}/alerts.log"
  ts="$(date -Is)"
  hostname="$(hostname -s 2>/dev/null || hostname)"

  mkdir -p "${alert_dir}"

  local schema schema_version project
  schema="homelab.alert"
  schema_version="${ALERT_SCHEMA_VERSION:-1.0}"
  project="homelab_2026.2"

  local payload
  if [[ -n "${details_json}" ]]; then
    payload="{\"schema\":\"${schema}\",\"schema_version\":\"${schema_version}\",\"project\":\"${project}\",\"timestamp\":\"${ts}\",\"host\":\"${hostname}\",\"component\":\"${component}\",\"severity\":\"${severity}\",\"message\":\"${message}\",\"details\":${details_json}}"
  else
    payload="{\"schema\":\"${schema}\",\"schema_version\":\"${schema_version}\",\"project\":\"${project}\",\"timestamp\":\"${ts}\",\"host\":\"${hostname}\",\"component\":\"${component}\",\"severity\":\"${severity}\",\"message\":\"${message}\"}"
  fi

  printf '%s\n' "${payload}" >>"${alert_log}"

  # Throttle remote notifications only.
  if ! _throttle_should_send "${component}" "${severity}"; then
    return 0
  fi

  if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    curl -fsS -X POST -H 'Content-Type: application/json' --data "${payload}" "${ALERT_WEBHOOK_URL}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${ALERT_SMTP_TO:-}" ]] && command -v sendmail >/dev/null 2>&1; then
    local subj from
    subj="[${severity}] ${project} ${component}"
    from="${ALERT_SMTP_FROM:-homelab@${hostname}}"
    {
      printf 'From: %s\n' "${from}"
      printf 'To: %s\n' "${ALERT_SMTP_TO}"
      printf 'Subject: %s\n' "${subj}"
      printf '\n'
      printf '%s\n' "${payload}"
    } | sendmail -t >/dev/null 2>&1 || true
  fi
}
