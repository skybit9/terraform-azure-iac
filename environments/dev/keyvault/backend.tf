# Backend values are supplied at init time by the pipeline via -backend-config.
# State for dev/keyvault lives in the MANAGEMENT subscription, in the
# dev storage account, in the tfstate-keyvault container.
terraform {
  backend "azurerm" {}
}
