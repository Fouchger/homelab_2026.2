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

## Health checks

The health check script validates:

- Router reachability
- HTTPS reachability (internet)
- DNS resolution via both dns01 and dns02 (when `dig` is present)

Status file:

- `/root/.config/homelab_2026_2/mikrotik/health.status`

## DNS high availability on MikroTik

When DHCP runs on MikroTik, you should advertise **both** DNS nodes.

Manual:

- Menu: **MikroTik integration** then **Configure DHCP to advertise dns01 + dns02**
- Or run: `scripts/mikrotik/configure-dns.sh`

The script updates:

- `/ip dhcp-server network ... dns-server=<dns01>,<dns02>`
- `/ip dns set servers=<dns01>,<dns02> allow-remote-requests=yes`
