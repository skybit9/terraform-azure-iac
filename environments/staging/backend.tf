# Backend config. Values supplied at init time via -backend-config flags in the
# pipeline so the same file works across environments.
terraform {
  backend "azurerm" {}
}
