# Consumed by downstream stacks through terraform_remote_state.
output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "app_subnet_id" {
  description = "Subnet the application workloads attach to"
  value       = azurerm_subnet.app.id
}
