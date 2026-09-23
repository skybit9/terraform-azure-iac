output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "DNS URI of the Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}
