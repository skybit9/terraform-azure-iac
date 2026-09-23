# Backend values are supplied at init time by the pipeline via -backend-config.
# State for staging/app lives in the MANAGEMENT subscription, in the
# staging storage account, in the tfstate-app container.
terraform {
  backend "azurerm" {}
}
