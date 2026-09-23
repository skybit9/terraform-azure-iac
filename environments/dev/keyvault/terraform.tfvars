key_vault_name      = "kv-leastops-dev"
resource_group_name = "rg-keyvault-dev"
location            = "canadacentral"

tags = {
  environment = "development"
  stack       = "keyvault"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
