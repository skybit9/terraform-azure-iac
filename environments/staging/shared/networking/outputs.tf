output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "app_subnet_id" {
  description = "Subnet application workloads attach to."
  value       = azurerm_subnet.app.id
}

output "app_subnet_nsg_id" {
  description = "Resource ID of the subnet NSG."
  value       = azurerm_network_security_group.app.id
}
