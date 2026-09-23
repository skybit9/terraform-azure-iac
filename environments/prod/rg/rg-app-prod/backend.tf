# Values supplied at init by the pipeline via -backend-config:
#   storage account : tfstateprod001 (management subscription)
#   container       : tfstate-rg-app-prod
#   key             : terraform.tfstate
#   use_azuread_auth: true (shared key access is disabled on the account)
terraform {
  backend "azurerm" {}
}
