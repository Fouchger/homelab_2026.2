# homelab_2026.2

A modular, Proxmox-first homelab automation repo designed for repeatable builds, safe day-two ops, and ongoing expansion.

## What this repo gives you now

1. A clean repo structure with reusable modules for services (DHCP, DNS, Active Directory, Talos, UDMS, admin node)
2. A professional TUI menu (spacebar selection when using dialog)
3. Catppuccin-themed logging to screen and per-run log files
4. A baseline bootstrap that can run on a brand-new Debian/Ubuntu node
5. Proxmox scripts to create an automation user/role/token and download common templates
6. Ansible roles and playbooks to configure core services and an admin node (including Code Server)
7. A Terraform scaffold using the bpg/proxmox provider, ready to wire up VM/LXC creation

## Quick start

On a new Debian/Ubuntu VM/LXC (no GUI required):

```bash
make bootstrap
make menu
```

If you are running from a freshly cloned repo, start here:

```bash
make menu
```

## Key concepts

Configuration is collected via questionnaires and stored locally in:

- `~/.config/homelab_2026_2/state.env`

Run logs are written per run to:

- `~/.config/homelab_2026_2/logs/*.log`

## Environment defaults used by this repo

- LAN: `192.168.88.0/24`
- Gateway: `192.168.88.1` (MikroTik)
- Proxmox node name default: `pve01`
- Storage default: `local-lvm`
- DHCP default location: MikroTik (recommended starting point)

## DNS provider options

You can choose the DNS stack at any time via **Menu → Settings and questionnaires**.

Supported providers:

- BIND9 (authoritative homelab zone + forwarders)
- AdGuard Home (filtering, UI)
- CoreDNS (Kubernetes aligned)
- Technitium DNS (feature-rich, UI)

Implementation notes are in `docs/dns.md`.

## Next build steps

This baseline is intentionally conservative. The next logical increments are:

1. Finalise your network conventions (VLANs, IP ranges, DNS zones, MikroTik integration)
2. Wire Terraform modules for LXC and VM provisioning (admin, dns, dhcp first)
3. Add Talos and UDMS provisioning once your template strategy is locked
4. Add a GitOps workflow for Kubernetes and Ansible inventory rendering

## Safety and secrets

This repo is designed so secrets are not committed to Git:

- Use SOPS for encrypting env files and Ansible vars
- Run Vaultwarden on the admin node for operational secrets

See `docs/standards.md` for the guardrails.

## MikroTik integration

Optional, but recommended for day-two operations:

- Scheduled MikroTik backups from admin01
- Health checks with a local status file
- DNS high availability advertisement to clients (dns01 + dns02)

See `docs/mikrotik.md`.

## Secrets workflow

Recommended pattern:

- Store source secrets in Vaultwarden
- Use SOPS for files that must exist on disk, decrypted only at runtime

See `docs/secrets.md`.
