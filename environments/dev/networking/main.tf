# ── STACK: networking (dev) ─────────────────────────────────────────────────
# Applied first. Downstream stacks read its outputs via terraform_remote_state.

resource "azurerm_virtual_network" "main" {
  name                = "vnet-dev"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.10.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Subnet level NSG. Defense in depth alongside the NIC level NSG the VM module
# creates. Azure default rules already deny inbound from the internet.
resource "azurerm_network_security_group" "app" {
  name                = "nsg-snet-app-dev"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
