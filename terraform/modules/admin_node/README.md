# Terraform module stub

This folder is intentionally a stub.

## Why it exists

homelab_2026.2 is designed to grow over time without breaking the repo structure. Each service gets a dedicated module so:

1. The module can be reused across environments.
2. Inputs and outputs are clear and testable.
3. We can migrate from LXC to VM (or vice versa) without rewriting the whole stack.

## What to wire in next

1. Decide whether this service should be a VM or an LXC.
2. Choose a base template (cloud image VM, or LXC template) and storage target.
3. Define networking conventions (VLANs, IP ranges, DNS, gateways).
4. Add resources using the `bpg/proxmox` provider.

## Outputs

Add outputs for:

- hostname
- IP address
- VMID/CTID
