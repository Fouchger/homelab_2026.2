// -----------------------------------------------------------------------------
// Filename: terraform/modules/admin_node/main.tf
// Created: 2026-01-18
// Description: Provision admin01 as a privileged Docker-capable LXC.
// Developer notes:
// - Admin node is the control plane for this project (Terraform + Ansible).
// - code-server is installed via Ansible by default.
// -----------------------------------------------------------------------------

module "admin01" {
  source = "../lxc"

  node_name = var.node_name
  vm_id     = var.vm_id
  name      = "admin01"

  bridge       = var.bridge
  ipv4_cidr    = var.ipv4_cidr
  ipv4_gateway = var.gateway

  dns_servers = var.dns_servers

  storage               = var.storage
  template_datastore_id = var.template_datastore_id
  template_url          = var.template_url
  template_file_name    = var.template_file_name

  ssh_public_key = var.ssh_public_key

  cores     = 4
  memory_mb = 4096
  swap_mb   = 1024
  rootfs_gb = 32

  tags = ["homelab_2026_2", "admin", "lxc"]
}
