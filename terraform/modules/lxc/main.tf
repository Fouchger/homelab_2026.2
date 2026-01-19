// -----------------------------------------------------------------------------
// Filename: terraform/modules/lxc/main.tf
// Created: 2026-01-18
// Description: Reusable LXC container for homelab_2026.2.
// Developer notes:
// - Downloads template onto Proxmox via proxmox_virtual_environment_download_file.
// - Uses static IPv4 via initialization.ip_config.
// -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_download_file" "template" {
  content_type = "vztmpl"
  datastore_id = var.template_datastore_id
  node_name    = var.node_name

  url       = var.template_url
  file_name = var.template_file_name
}

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = "Managed by Terraform (homelab_2026.2)"
  tags        = var.tags

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = length(var.dns_servers) > 0 ? var.dns_servers : null
    }

    user_account {
      keys     = [trimspace(var.ssh_public_key)]
      password = null
      username = "root"
    }
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  network_interface {
    name   = "veth0"
    bridge = var.bridge
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.template.id
    type             = "ubuntu"
  }

  disk {
    datastore_id = var.storage
    size         = "${var.rootfs_gb}G"
  }

  unprivileged = var.privileged ? false : true

  features {
    nesting = var.enable_docker_features
    keyctl  = var.enable_docker_features
  }

  start_on_boot = true
}
