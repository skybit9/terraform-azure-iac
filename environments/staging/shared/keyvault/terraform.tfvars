key_vault_name      = "kv-leastops-staging"
resource_group_name = "rg-keyvault-staging"
location            = "canadacentral"

tags = {
  environment = "staging"
  stack       = "keyvault"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
