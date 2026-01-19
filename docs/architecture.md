# Architecture overview

## Intent

homelab_2026.2 aims to make your Proxmox environment repeatable, auditable, and easy to evolve.

## Control plane

The admin node acts as the control plane:

1. Terraform provisions VMs/LXCs in Proxmox
2. Ansible configures those machines and keeps them up to date
3. SOPS manages encrypted configuration and secrets-at-rest
4. Vaultwarden provides a practical secrets UI for day-to-day operations

## Key design choices

1. Modular services. Each service has a clear boundary and can be enabled or disabled without affecting unrelated services.
2. Idempotence first. Re-running the same target should converge, not break.
3. Safe defaults. Destructive actions require explicit confirmation.
4. Full observability. Each run writes to a time-stamped log file and also streams to the screen.

## What is intentionally not hardcoded

Network layout, VLANs, IP ranges, and DNS zone structure are not assumed. These vary widely between MikroTik setups.
