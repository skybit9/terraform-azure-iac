# ── STACK: networking (prod) ──────────────────────────────────────────────────
# Owns the VNet and subnets. Downstream stacks consume the subnet IDs via
# terraform_remote_state, so this stack applies first.

resource "azurerm_virtual_network" "main" {
  name                = "vnet-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.30.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.30.1.0/24"]
}
