# DNS options

This repo supports multiple DNS stacks so you can evolve your setup without rewiring the whole homelab.

## How to choose

Use Menu → Settings and questionnaires → DNS provider.

The choice is persisted in `~/.config/homelab_2026_2/state.env` as `DNS_PROVIDER` and passed into Ansible as `homelab_dns_provider`.

## Provider comparison

### BIND9

Best when you want a stable, conventional authoritative zone for your LAN plus upstream forwarding.

Pros

- Mature and predictable
- Easy to run in LXC without Docker

Cons

- No built-in UI
- Filtering and client reporting require extra tooling

### AdGuard Home

Best when you want a user-friendly UI, client reporting, and ad blocking.

Pros

- Excellent UX
- Built-in filtering lists

Cons

- This repo deploys it via Docker, which is not ideal on unprivileged LXCs
- Treat as an application, not an infrastructure primitive

### CoreDNS

Best when you want alignment with Kubernetes patterns and a straightforward config model.

Pros

- Lightweight binary + systemd
- Strong fit for future Talos and Kubernetes integration

Cons

- Less familiar for traditional DNS troubleshooting
- No built-in UI

### Technitium DNS

Best when you want a feature-rich DNS service with a strong UI and a broad feature set.

Pros

- UI-driven management
- Strong feature coverage

Cons

- This repo deploys it via Docker, which is not ideal on unprivileged LXCs

## Security and resilience notes

- Start with DHCP on MikroTik and run DNS in Proxmox.
- When you switch DHCP later, update DHCP option 6 to point to the chosen DNS servers.
- For higher resilience, run two DNS servers (primary and secondary) and configure clients accordingly.
