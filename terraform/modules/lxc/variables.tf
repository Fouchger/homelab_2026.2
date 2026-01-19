// -----------------------------------------------------------------------------
// Filename: terraform/modules/lxc/variables.tf
// Created: 2026-01-18
// Description: Reusable LXC module (privileged by default, Docker-capable).
// Developer notes:
// - Enables nesting + keyctl by default to support Docker-in-LXC.
// - Privileged containers reduce isolation; use VMs for higher-risk workloads.
// -----------------------------------------------------------------------------

variable "node_name" { type = string }
variable "vm_id" { type = number }
variable "name" { type = string }

variable "bridge" { type = string }
variable "ipv4_cidr" { type = string }
variable "ipv4_gateway" { type = string }

variable "dns_servers" {
  description = "Optional DNS servers for the container (list of IPv4 addresses)"
  type        = list(string)
  default     = []
}

variable "storage" { type = string }

variable "template_datastore_id" {
  description = "Datastore used for LXC templates (typically 'local')"
  type        = string
  default     = "local"
}

variable "template_url" {
  description = "URL for the LXC template tarball (.tar.zst)"
  type        = string
}

variable "template_file_name" {
  description = "File name to store on Proxmox for the template"
  type        = string
}

variable "cores" { type = number default = 2 }
variable "memory_mb" { type = number default = 2048 }
variable "swap_mb" { type = number default = 512 }
variable "rootfs_gb" { type = number default = 8 }

variable "tags" {
  description = "Proxmox tags"
  type        = list(string)
  default     = ["homelab_2026_2", "terraform"]
}

variable "ssh_public_key" {
  description = "Public key injected into root account"
  type        = string
}

variable "privileged" {
  description = "Create privileged container"
  type        = bool
  default     = true
}

variable "enable_docker_features" {
  description = "Enable nesting/keyctl features to support Docker-in-LXC"
  type        = bool
  default     = true
}
