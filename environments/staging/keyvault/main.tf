# ── STACK: keyvault (staging) ────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Both required by policy: soft delete is not optional in Azure, purge
  # protection prevents permanent deletion during the retention window.
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # RBAC mode rather than access policies: assignments are visible in
  # Azure RBAC and manageable the same way as every other resource.
  enable_rbac_authorization = true

  tags = var.tags
}
