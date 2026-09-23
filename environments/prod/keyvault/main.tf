# ── STACK: keyvault (prod) ───────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # RBAC mode: access is granted with Azure role assignments, not access
  # policies. (azurerm 4.x name; enable_rbac_authorization is deprecated.)
  rbac_authorization_enabled = true

  # Public endpoint stays reachable because Microsoft hosted pipeline agents
  # write the VM SSH secrets from outside the VNet. Hardening path: private
  # endpoint plus a self hosted agent inside the VNet, then set
  # public_network_access_enabled = false and default_action = "Deny".
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    default_action = var.network_default_action
    bypass         = "AzureServices"
  }

  tags = var.tags
}
