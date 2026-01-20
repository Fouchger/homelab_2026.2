
# homelab_2026.2 – User Manual <!-- omit from toc -->

---

## Table of Contents <!-- omit from toc -->

<!-- TOC start -->
<!-- markdownlint-disable MD004 MD007 -->

- [1. Purpose and Vision](#1-purpose-and-vision)
- [2. Supported Environment](#2-supported-environment)
  - [2.1 Infrastructure](#21-infrastructure)
  - [2.2 Execution Nodes](#22-execution-nodes)
- [3. High-Level Architecture](#3-high-level-architecture)
  - [3.1 Control Flow](#31-control-flow)
  - [3.2 Tooling Responsibilities](#32-tooling-responsibilities)
- [4. Bootstrap Process](#4-bootstrap-process)
  - [4.1 First Run (Greenfield)](#41-first-run-greenfield)
  - [4.2 Existing Environment (Brownfield)](#42-existing-environment-brownfield)
- [5. Proxmox Integration](#5-proxmox-integration)
  - [5.1 API Access](#51-api-access)
  - [5.2 Resource Management](#52-resource-management)
- [6. Core Service Modules](#6-core-service-modules)
  - [6.1 DNS (Selectable)](#61-dns-selectable)
  - [6.2 DHCP](#62-dhcp)
  - [6.3 Active Directory](#63-active-directory)
  - [6.4 Kubernetes](#64-kubernetes)
  - [6.5 UDMS](#65-udms)
- [7. MikroTik Integration (Optional but Recommended)](#7-mikrotik-integration-optional-but-recommended)
  - [7.1 Configuration Backup](#71-configuration-backup)
  - [7.2 Health Checks](#72-health-checks)
  - [7.3 Alerting](#73-alerting)
- [8. Security and Secrets](#8-security-and-secrets)
  - [8.1 Secrets Management](#81-secrets-management)
  - [8.2 Docker Usage](#82-docker-usage)
- [9. Interactive Menu System](#9-interactive-menu-system)
  - [9.1 Design](#91-design)
  - [9.2 Capabilities](#92-capabilities)
- [10. Logging and Observability](#10-logging-and-observability)
  - [10.1 Logging](#101-logging)
  - [10.2 Self-Healing](#102-self-healing)
- [11. Development Standards](#11-development-standards)
  - [11.1 Code Standards](#111-code-standards)
  - [11.2 Formatting and Tooling](#112-formatting-and-tooling)
  - [11.3 Repository Structure](#113-repository-structure)
- [12. Operational Best Practice](#12-operational-best-practice)
  - [12.1 Stability First](#121-stability-first)
  - [12.2 Growth Path](#122-growth-path)
- [13. Known Limitations](#13-known-limitations)
- [14. Next Steps](#14-next-steps)

<!-- markdownlint-enable MD004 MD007 -->
<!-- TOC end -->

---

## 1. Purpose and Vision

homelab_2026.2 is a modular, production-grade homelab automation framework designed for Proxmox VE (latest).
The platform provides a repeatable, self-healing way to bootstrap, deploy, operate, and evolve a full homelab
using open-source tooling only.

The design philosophy is “no regrets”: sensible defaults, opt-in complexity, and the ability to grow without rework.

---

## 2. Supported Environment

### 2.1 Infrastructure

- Proxmox VE: latest supported version
- Storage: local-lvm (default), extensible to ZFS, NFS, or Ceph
- Network: single flat network
  - Subnet: 192.168.88.0/24
  - Router: MikroTik (physical), with optional virtual MikroTik on Proxmox
- No VLAN dependency

### 2.2 Execution Nodes

- admin01: privileged LXC or VM
  - Primary control plane
  - Ansible, Terraform, Packer, Make, Python
  - code-server installed
- Target nodes: LXCs preferred, VMs where required

---

## 3. High-Level Architecture

### 3.1 Control Flow

1. Bootstrap script run
2. s on admin01 or fresh VM/LXC
2. GitHub repository is cloned locally
3. Baseline dependencies are installed
4. Ansible becomes the system of record
5. Terraform manages Proxmox resources
6. Packer builds reusable templates
7. Ongoing management via interactive menu

### 3.2 Tooling Responsibilities

- Make: orchestration and task entrypoints
- Ansible: configuration, idempotency, drift correction
- Terraform: VM/LXC lifecycle
- Packer: golden images and templates
- Python: menus, questionnaires, validation, glue logic

---

## 4. Bootstrap Process

### 4.1 First Run (Greenfield)

- Minimal OS required
- Network connectivity only
- Script will:
  - Install baseline packages
  - Configure SSH and Python
  - Clone repository
  - Request Proxmox API credentials
  - Hand off to Ansible

### 4.2 Existing Environment (Brownfield)
- Discovery mode enabled
- System interrogates Proxmox API
- Existing VMs/LXCs imported into state
- Missing metadata requested interactively

---

## 5. Proxmox Integration

### 5.1 API Access
A dedicated Proxmox user, role, and API token are created using:
- bootstrap-api-token.sh

Naming convention (standard):
- User: homelab-automation
- Role: HomelabAutomationRole
- Token: homelab_2026_2_token

Least-privilege access is enforced.

### 5.2 Resource Management
- Create, destroy, rebuild LXCs and VMs
- Tagging and naming standards enforced
- State reconciliation supported

---

## 6. Core Service Modules

### 6.1 DNS (Selectable)
User may deploy one or more:
- BIND9
- AdGuard Home
- CoreDNS
- Technitium

Features:
- Active-active DNS nodes
- MikroTik advertises both resolvers
- Health checks from admin01
- Optional migration from MikroTik DNS to Proxmox-hosted DNS

### 6.2 DHCP
- Default: MikroTik
- Optional: Linux-based DHCP in Proxmox

### 6.3 Active Directory
- Samba AD (open source)
- LXC preferred
- Integrated DNS optional

### 6.4 Kubernetes
- Talos on Proxmox
- GitOps-ready
- Integrated with Terraform

### 6.5 UDMS
- Treated as standalone stack
- Deployed and managed from admin01
- No coupling to core services

---

## 7. MikroTik Integration (Optional but Recommended)

### 7.1 Configuration Backup
- Automated exports from admin01
- Retention policy:
  - Keep last N backups
  - Old files pruned automatically

### 7.2 Health Checks
- Connectivity
- DNS forwarding status
- Config drift detection

### 7.3 Alerting
- Local structured logs
- Webhook and SMTP hooks (opt-in)

---

## 8. Security and Secrets

### 8.1 Secrets Management
- SOPS for encryption
- Vaultwarden as secret backend
- Runtime secret injection only
- No sensitive material committed to GitHub

### 8.2 Docker Usage
- Allowed on admin01
- Used for tooling only
- No stateful workloads

---

## 9. Interactive Menu System

### 9.1 Design
- Runs in TTY or GUI
- Spacebar-based selection
- Inspired by Ubuntu LXC app manager
- Catppuccin theming
  - All flavours supported
- Emoji-enhanced but professional

### 9.2 Capabilities
- Deploy services
- Destroy services
- Repair services
- Run health checks
- View logs

---

## 10. Logging and Observability

### 10.1 Logging
- Per-run log file
- Colour-coded console output
- Levels: INFO, WARN, ERROR, SUCCESS

### 10.2 Self-Healing
- Drift detection
- Missing files regenerated
- User prompted only when required

---

## 11. Development Standards

### 11.1 Code Standards
- Every file includes:
  - Header block
  - Purpose
  - Author
  - Last modified
- Inline developer notes where decisions matter

### 11.2 Formatting and Tooling
- Markdownlint compliant
- Prettier compliant
- Pre-commit hooks enforced

### 11.3 Repository Structure
- Clear separation:
  - bootstrap
  - ansible
  - terraform
  - packer
  - scripts
  - docs

---

## 12. Operational Best Practice

### 12.1 Stability First
- LXCs preferred
- Minimal moving parts
- DNS and admin node treated as tier-0

### 12.2 Growth Path
- VLANs optional later
- Storage backend abstracted
- Cloud-init and image pipelines ready

---

## 13. Known Limitations
- No proprietary software
- No licensed hypervisors
- Single physical Proxmox node assumed initially

---

## 14. Next Steps
- Review module selection
- Run bootstrap on admin01
- Deploy DNS HA
- Add services incrementally

---

End of document.
