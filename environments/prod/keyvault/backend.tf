# Backend values are supplied at init time by the pipeline via -backend-config.
# State for prod/keyvault lives in the MANAGEMENT subscription, in the
# prod storage account, in the tfstate-keyvault container.
terraform {
  backend "azurerm" {}
}
