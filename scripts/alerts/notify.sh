#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/alerts/notify.sh
# Created: 2026-01-19
# Description: Opt-in alerting helper for homelab_2026.2.
# Usage:
#   source "${REPO_ROOT}/scripts/alerts/notify.sh"
#   notify_event "mikrotik" "ERROR" "Health check failed" '{"failures":["dns01"]}'
# Developer notes:
#   - Always appends an alert line to a local log.
#   - Optional channels:
#       * Webhook: set ALERT_WEBHOOK_URL (expects JSON POST)
#       * SMTP: set ALERT_SMTP_TO and ensure sendmail is available (msmtp works)
#   - Do not store credentials in state.env. If SMTP auth is needed, fetch the
#     password at runtime using Vaultwarden + SOPS, then export SMTP_PASSWORD.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

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

  local payload
  if [[ -n "${details_json}" ]]; then
    payload="{\"timestamp\":\"${ts}\",\"host\":\"${hostname}\",\"component\":\"${component}\",\"severity\":\"${severity}\",\"message\":\"${message}\",\"details\":${details_json}}"
  else
    payload="{\"timestamp\":\"${ts}\",\"host\":\"${hostname}\",\"component\":\"${component}\",\"severity\":\"${severity}\",\"message\":\"${message}\"}"
  fi

  printf '%s\n' "${payload}" >>"${alert_log}"

  if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    curl -fsS -X POST -H 'Content-Type: application/json' --data "${payload}" "${ALERT_WEBHOOK_URL}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${ALERT_SMTP_TO:-}" ]] && command -v sendmail >/dev/null 2>&1; then
    local subj from
    subj="[${severity}] homelab_2026.2 ${component}"
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
