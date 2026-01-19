// -----------------------------------------------------------------------------
// Filename: terraform/modules/lxc/outputs.tf
// Created: 2026-01-18
// Description: Outputs for the LXC module.
// -----------------------------------------------------------------------------

output "name" { value = var.name }
output "vm_id" { value = var.vm_id }
output "ipv4_cidr" { value = var.ipv4_cidr }
output "ipv4_address" { value = split("/", var.ipv4_cidr)[0] }
