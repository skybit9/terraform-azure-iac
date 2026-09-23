# azurerm 4.x requires an explicit subscription_id.
# Supplied via ARM_SUBSCRIPTION_ID environment variable in the pipeline.
provider "azurerm" {
  features {}
}
