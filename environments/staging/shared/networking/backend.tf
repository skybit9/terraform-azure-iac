# Values supplied at init by the pipeline via -backend-config:
#   storage account : tfstatestaging001 (management subscription)
#   container       : tfstate-networking
#   key             : terraform.tfstate
#   use_azuread_auth: true (shared key access is disabled on the account)
terraform {
  backend "azurerm" {}
}
