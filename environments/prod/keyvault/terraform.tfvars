key_vault_name      = "kv-ishelar-prod"
resource_group_name = "rg-keyvault-prod"
location            = "canadacentral"

tags = {
  environment = "production"
  stack       = "keyvault"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
