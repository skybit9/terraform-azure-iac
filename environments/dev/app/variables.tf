variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for this stack"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "vm_size" {
  type        = string
  description = "VM SKU"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB"
  default     = 128
}

variable "os_disk_type" {
  type        = string
  description = "Managed disk type"
  default     = "Premium_LRS"
}

variable "nsg_allowed_ssh_source" {
  type        = string
  description = "Private CIDR permitted to reach port 22"
}

# Remote state location of the upstream stacks
variable "state_resource_group" {
  type        = string
  description = "Resource group holding the state storage accounts"
}

variable "state_storage_account" {
  type        = string
  description = "State storage account for this environment"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}
