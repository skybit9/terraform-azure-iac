# Backend values are supplied at init time by the pipeline via -backend-config.
# State for prod/networking lives in the MANAGEMENT subscription, in the
# prod storage account, in the tfstate-networking container.
terraform {
  backend "azurerm" {}
}
