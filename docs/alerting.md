# Alerting

This project supports lightweight, opt-in alerting for operational checks (for example MikroTik health checks).

## Local logs

All alerts are written as JSON lines to:

- `~/.config/homelab_2026_2/alerts/alerts.log`

MikroTik health check failures are also appended to:

- `~/.config/homelab_2026_2/mikrotik/health.failures.log`

## Webhook (optional)

Set a webhook URL in questionnaires:

- **Settings and questionnaires** -> **Alerting** -> Webhook URL

Or set it manually in `~/.config/homelab_2026_2/state.env`:

- `ALERT_WEBHOOK_URL=https://your-endpoint.example/alerts`

The webhook receives an HTTP POST with `Content-Type: application/json`.

## SMTP (optional)

This is intentionally minimal and designed to be extended later.

Configuration:

- `ALERT_SMTP_TO=you@example.com`
- `ALERT_SMTP_FROM=homelab@example.com` (optional)

Requirement:

- A working `sendmail` implementation (the admin role installs `msmtp-mta`).

If you need SMTP auth, do not store passwords in Git or in `state.env`. Fetch a password at runtime (Vaultwarden + SOPS), export it into the session, and have `msmtp` reference it.

## Payload schema and versioning

Webhook and SMTP payloads include:

- `schema`: `homelab.alert`
- `schema_version`: defaults to `1.0`
- `project`: `homelab_2026.2`

You can override the schema version (advanced) via:

- `ALERT_SCHEMA_VERSION=1.0`

## Throttling

To avoid alert spam, webhook and SMTP notifications are throttled by default. Local logging always happens.

Configuration (in `~/.config/homelab_2026_2/state.env` or exported in your shell):

- `ALERT_THROTTLE_SECONDS` (default: `900`). Set to `0` to disable throttling.
- `ALERT_THROTTLE_KEY_MODE`:
  - `component_severity` (default)
  - `component`
