// -----------------------------------------------------------------------------
// Filename: terraform/modules/dns/outputs.tf
// Created: 2026-01-18
// Description: Outputs for DNS module.
// -----------------------------------------------------------------------------

output "hosts" {
  description = "DNS hosts (name -> ipv4)"
  value = {
    dns01 = module.dns01.ipv4_address
    dns02 = module.dns02.ipv4_address
  }
}
