// -----------------------------------------------------------------------------
// Filename: terraform/modules/admin_node/outputs.tf
// Created: 2026-01-18
// Description: Outputs for the admin node module.
// -----------------------------------------------------------------------------

output "host" {
  value = {
    name = module.admin01.name
    ipv4 = module.admin01.ipv4_address
    vm_id = module.admin01.vm_id
  }
}
