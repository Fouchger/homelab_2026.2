// -----------------------------------------------------------------------------
// Filename: terraform/modules/dns/variables.tf
// Created: 2026-01-18
// Description: DNS module provisioning two DNS LXCs (dns01 + dns02).
// Developer notes:
// - DNS software is installed via Ansible; Terraform only provisions compute.
// -----------------------------------------------------------------------------

variable "node_name" { type = string }
variable "bridge" { type = string }
variable "storage" { type = string }

variable "dns_ips" {
  description = "Static IPs (CIDR) for dns01 and dns02"
  type        = list(string)
}

variable "gateway" { type = string }

variable "template_datastore_id" { type = string default = "local" }

variable "template_url" {
  description = "LXC template URL (.tar.zst)"
  type        = string
}

variable "template_file_name" {
  description = "File name for template on Proxmox"
  type        = string
}

variable "ssh_public_key" { type = string }

variable "vmid_base" {
  description = "Base VMID; dns01 gets vmid_base, dns02 gets vmid_base+1"
  type        = number
  default     = 210
}
