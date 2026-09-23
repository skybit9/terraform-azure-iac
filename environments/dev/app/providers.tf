provider "azurerm" {
  features {}

  # Auth: workload identity federation. The pipeline exports ARM_CLIENT_ID,
  # ARM_TENANT_ID, ARM_SUBSCRIPTION_ID and ARM_OIDC_TOKEN. No client secret.
  use_oidc = true

  # azurerm 4.x otherwise auto-registers resource providers at SUBSCRIPTION
  # scope, which fails for identities scoped to a resource group. Providers are
  # registered once by bootstrap/05-providers.sh instead.
  resource_provider_registrations = "none"
}
