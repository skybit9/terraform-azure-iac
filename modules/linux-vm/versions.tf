# ── PROVIDER VERSION PINS ─────────────────────────────────────────────────────
# Always pin provider versions in modules. Never use >= without an upper bound
# in production; a major version bump can introduce breaking changes silently.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
