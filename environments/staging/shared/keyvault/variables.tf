variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name, 3 to 24 characters."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for this stack."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Keep true while pipelines use Microsoft hosted agents."
  default     = true
}

variable "network_default_action" {
  type        = string
  description = "Allow or Deny. Set Deny once a private endpoint and self hosted agent exist."
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be Allow or Deny."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
