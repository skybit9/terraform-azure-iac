variable "resource_group_name" {
  type        = string
  description = "Resource group for this stack."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "nsg_allowed_ssh_source" {
  type        = string
  description = "Private CIDR permitted to reach port 22 on the VMs."
}

variable "state_resource_group" {
  type        = string
  description = "Resource group holding the state storage accounts (management subscription)."
}

variable "state_storage_account" {
  type        = string
  description = "State storage account for this environment."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
