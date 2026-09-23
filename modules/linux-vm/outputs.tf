# ── OUTPUTS ───────────────────────────────────────────────────────────────────

output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "private_ip_address" {
  description = "Private IP address assigned to the NIC"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "nic_id" {
  description = "Resource ID of the network interface"
  value       = azurerm_network_interface.vm.id
}

output "nsg_id" {
  description = "Resource ID of the network security group"
  value       = azurerm_network_security_group.vm.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the VM system assigned managed identity"
  value       = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

output "ssh_private_key_secret_name" {
  description = "Name of the Key Vault secret holding the SSH private key"
  value       = azurerm_key_vault_secret.ssh_private_key.name
}
