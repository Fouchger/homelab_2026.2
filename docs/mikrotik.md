# MikroTik integration

## What this does

From **admin01**, this project can:

- Create RouterOS backups (text export + binary backup) and store them locally.
- Run regular health checks and write a small status file.
- Update MikroTik DHCP to advertise **dns01 + dns02** for DNS high availability.

Nothing in this module requires committing credentials to Git.

## Prerequisites

- Enable SSH on your MikroTik.
- Prefer SSH key auth. If you must use password auth, export `MIKROTIK_SSH_PASSWORD` for the duration of a manual run.

## Configuration

Run the questionnaires:

- `make menu` then **Settings and questionnaires**
- Complete **MikroTik connection**

These values are stored in `~/.config/homelab_2026_2/state.env`.

## Backups

Manual:

- Menu: **MikroTik integration** then **Backup MikroTik now**
- Or run: `scripts/mikrotik/backup.sh`

Scheduled:

- The Ansible role `mikrotik_integration` deploys systemd timers on admin01.
- Default schedule is daily at 03:15.

Backup location on admin01:

- `/root/.config/homelab_2026_2/mikrotik/backups`

Retention policy:

- Keep last **N** backup sets (export + binary) per router.
- Configurable via `MIKROTIK_BACKUP_RETENTION_COUNT` in `state.env`.
- Default is `30`. Set to `0` to disable pruning.

## Start config import (opt-in)

You can optionally import a baseline RouterOS `.rsc` file.

- Menu: **MikroTik** then **Install start config locally** and **Apply start config to MikroTik**.
- The config file lives locally at `~/.config/homelab_2026_2/mikrotik/start_config.rsc`.

Important:

- Importing an RSC can change networking. Run this only when you have console access or a safe rollback plan.
- The repository may include a `.local/` example, but `.local/` is gitignored so you do not leak device identifiers.

## Health checks

The health check script validates:

- Router reachability
- HTTPS reachability (internet)
- DNS resolution via both dns01 and dns02 (when `dig` is present)

Status file:

- `/root/.config/homelab_2026_2/mikrotik/health.status`

Alerting:

- Failures are appended to `/root/.config/homelab_2026_2/mikrotik/health.failures.log`.
- Alerts are also recorded in JSON at `/root/.config/homelab_2026_2/alerts/alerts.log`.
- Optional webhook: set `ALERT_WEBHOOK_URL`.
- Optional SMTP: set `ALERT_SMTP_TO` (and `ALERT_SMTP_FROM` if needed) and ensure a `sendmail` implementation is available (the admin role installs `msmtp-mta`).

## DNS high availability on MikroTik

When DHCP runs on MikroTik, you should advertise **both** DNS nodes.

Manual:

- Menu: **MikroTik integration** then **Configure DHCP to advertise dns01 + dns02**
- Or run: `scripts/mikrotik/configure-dns.sh`

The script updates:

- `/ip dhcp-server network ... dns-server=<dns01>,<dns02>`
- `/ip dns set servers=<dns01>,<dns02> allow-remote-requests=yes`
