# LXC module

Reusable module to provision a Proxmox LXC container using the **bpg/proxmox** provider.

## Design intent

This module defaults to a privileged container with nesting and keyctl enabled, which is commonly required for Docker-in-LXC.

## Security notes

Privileged containers are less isolated than unprivileged ones. Where feasible, prefer unprivileged containers with rootless containers, or use a VM for higher-risk workloads.
