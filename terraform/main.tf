// -----------------------------------------------------------------------------
// Filename: terraform/main.tf
// Created: 2026-01-18
// Description: Terraform root configuration for homelab_2026.2.
// Developer notes:
// - Provisioning only; application configuration is handled by Ansible.
// - Defaults assume DHCP stays on MikroTik. If you later move DHCP into Proxmox,
//   add the dhcp module back into target_services.
// -----------------------------------------------------------------------------

provider "proxmox" {
  endpoint         = var.proxmox_api_url
  api_token        = var.proxmox_token_id
  api_token_secret = var.proxmox_token_secret
  insecure         = true

  ssh {
    agent = true
  }
}

locals {
  services = toset(var.target_services)
}

module "admin_node" {
  source = "./modules/admin_node"
  count  = contains(local.services, "admin") ? 1 : 0

  node_name = var.node_name
  bridge    = var.bridge
  storage   = var.storage

  ipv4_cidr = var.service_ips["admin01"]
  gateway   = var.lan_gateway

  # Prefer your homelab DNS once provisioned.
  dns_servers = [
    split("/", var.service_ips["dns01"])[0],
    split("/", var.service_ips["dns02"])[0]
  ]

  template_datastore_id = var.template_datastore_id
  template_url          = var.lxc_template_url
  template_file_name    = var.lxc_template_file_name

  ssh_public_key = var.ssh_public_key
}

module "dns" {
  source = "./modules/dns"
  count  = contains(local.services, "dns") ? 1 : 0

  node_name = var.node_name
  bridge    = var.bridge
  storage   = var.storage

  dns_ips  = [var.service_ips["dns01"], var.service_ips["dns02"]]
  gateway  = var.lan_gateway

  template_datastore_id = var.template_datastore_id
  template_url          = var.lxc_template_url
  template_file_name    = var.lxc_template_file_name

  ssh_public_key = var.ssh_public_key
}
