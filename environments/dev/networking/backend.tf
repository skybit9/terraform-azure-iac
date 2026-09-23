# Backend values are supplied at init time by the pipeline via -backend-config.
# State for dev/networking lives in the MANAGEMENT subscription, in the
# dev storage account, in the tfstate-networking container.
terraform {
  backend "azurerm" {}
}
