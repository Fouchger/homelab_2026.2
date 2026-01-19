// -----------------------------------------------------------------------------
// Filename: terraform/modules/dns/main.tf
// Created: 2026-01-18
// Description: Provision dns01 and dns02 as privileged LXCs.
// Developer notes:
// - We keep DNS provisioning simple: 2x LXCs with static IPs.
// - DNS provider selection (BIND9, AdGuard Home, CoreDNS, Technitium) is
//   handled by Ansible via questionnaire settings.
// -----------------------------------------------------------------------------

module "dns01" {
  source = "../lxc"

  node_name   = var.node_name
  vm_id       = var.vmid_base
  name        = "dns01"

  bridge      = var.bridge
  ipv4_cidr   = var.dns_ips[0]
  ipv4_gateway = var.gateway

  # Avoid circular dependencies: DNS containers should be able to resolve even
  # before DNS is configured.
  dns_servers = []

  storage              = var.storage
  template_datastore_id = var.template_datastore_id
  template_url         = var.template_url
  template_file_name   = var.template_file_name

  ssh_public_key = var.ssh_public_key

  cores      = 2
  memory_mb  = 1024
  swap_mb    = 512
  rootfs_gb  = 8

  tags = ["homelab_2026_2", "dns", "lxc"]
}

module "dns02" {
  source = "../lxc"

  node_name   = var.node_name
  vm_id       = var.vmid_base + 1
  name        = "dns02"

  bridge      = var.bridge
  ipv4_cidr   = var.dns_ips[1]
  ipv4_gateway = var.gateway

  dns_servers = []

  storage              = var.storage
  template_datastore_id = var.template_datastore_id
  template_url         = var.template_url
  template_file_name   = var.template_file_name

  ssh_public_key = var.ssh_public_key

  cores      = 2
  memory_mb  = 1024
  swap_mb    = 512
  rootfs_gb  = 8

  tags = ["homelab_2026_2", "dns", "lxc"]
}
