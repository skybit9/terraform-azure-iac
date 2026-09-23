variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "resource_group_name" {
  type        = string
  description = "Target resource group"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the NIC. Supplied by the pipeline from the networking module output"
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault holding the generated SSH private key"
}

variable "vm_size" {
  type        = string
  description = "VM SKU"
  default     = "Standard_D2s_v3"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}
