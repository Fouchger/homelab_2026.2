// -----------------------------------------------------------------------------
// Filename: terraform/outputs.tf
// Created: 2026-01-18
// Description: Outputs used to generate Ansible inventory.
// -----------------------------------------------------------------------------

output "admin" {
  value       = length(module.admin_node) > 0 ? module.admin_node[0].host : null
  description = "Admin node details"
}

output "dns" {
  value       = length(module.dns) > 0 ? module.dns[0].hosts : {}
  description = "DNS nodes (name -> ipv4)"
}
