# azurerm 4.x requires an explicit subscription. Supplied by the pipeline as
# ARM_SUBSCRIPTION_ID. Auth is via workload identity federation, no secrets.
provider "azurerm" {
  features {}
  use_oidc = true
}
