// -----------------------------------------------------------------------------
// Filename: terraform/variables.tf
// Created: 2026-01-18
// Description: Input variables for homelab_2026.2.
// Developer notes:
// - Do not hardcode secrets. Token secret is loaded from the token file and
//   exported as TF_VAR_proxmox_token_secret.
// -----------------------------------------------------------------------------

variable "proxmox_host" {
  description = "Proxmox hostname or IP"
  type        = string
}

variable "proxmox_api_url" {
  description = "Proxmox API URL, e.g. https://pve:8006/api2/json"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token id, e.g. user@pve!token"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve01"
}

variable "target_services" {
  description = "Which services to provision"
  type        = list(string)
  default     = ["admin", "dns"]
}

variable "lan_cidr" {
  description = "LAN CIDR"
  type        = string
  default     = "192.168.88.0/24"
}

variable "lan_gateway" {
  description = "Default gateway (typically MikroTik)"
  type        = string
  default     = "192.168.88.1"
}

variable "lan_domain" {
  description = "Local DNS search domain"
  type        = string
  default     = "home.arpa"
}

variable "bridge" {
  description = "Proxmox bridge name"
  type        = string
  default     = "vmbr0"
}

variable "storage" {
  description = "Default Proxmox storage ID"
  type        = string
  default     = "local-lvm"
}

variable "template_datastore_id" {
  description = "Datastore used for templates (typically 'local')"
  type        = string
  default     = "local"
}

variable "lxc_template_url" {
  description = "Default LXC template URL (.tar.zst)"
  type        = string
  default     = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-1_amd64.tar.zst"
}

variable "lxc_template_file_name" {
  description = "Default LXC template file name"
  type        = string
  default     = "ubuntu-24.04-standard_24.04-1_amd64.tar.zst"
}

variable "ssh_public_key" {
  description = "SSH public key for root login"
  type        = string
}

variable "service_ips" {
  description = "Static IPv4 assignments per service (CIDR)"
  type        = map(string)
  default = {
    admin01 = "192.168.88.10/24"
    dns01   = "192.168.88.2/24"
    dns02   = "192.168.88.3/24"
    ad01    = "192.168.88.4/24"
    udms01  = "192.168.88.20/24"
  }
}
