// -----------------------------------------------------------------------------
// Filename: terraform/versions.tf
// Created: 2026-01-18
// Description: Terraform and provider versions for homelab_2026.2.
// Developer notes:
// - Pin provider versions to reduce drift.
// -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}
