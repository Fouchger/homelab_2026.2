// -----------------------------------------------------------------------------
// Filename: terraform/modules/admin_node/variables.tf
// Created: 2026-01-18
// Description: Admin node module for homelab_2026.2.
// Developer notes:
// - Provisioning only; configuration (code-server, docker, tooling) via Ansible.
// -----------------------------------------------------------------------------

variable "node_name" { type = string }
variable "bridge" { type = string }
variable "storage" { type = string }

variable "ipv4_cidr" { type = string }
variable "gateway" { type = string }

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "template_datastore_id" { type = string default = "local" }
variable "template_url" { type = string }
variable "template_file_name" { type = string }

variable "ssh_public_key" { type = string }

variable "vm_id" {
  description = "VMID for admin LXC"
  type        = number
  default     = 200
}
