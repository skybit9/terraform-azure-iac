variable "vm_name" {
  type        = string
  description = "Name of the virtual machine. Every child resource name is derived from it."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group the VM and its NIC and NSG are deployed into."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the NIC. The VM receives a private IP only."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault (RBAC mode) that receives the generated SSH key pair."
}

variable "vm_size" {
  type        = string
  description = "VM SKU."
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  type        = string
  description = "Admin username. Password authentication is disabled."
  default     = "azureadmin"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB."
  default     = 128
}

variable "os_disk_type" {
  type        = string
  description = "Managed disk type for the OS disk."
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Premium_LRS", "StandardSSD_LRS", "Standard_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be Premium_LRS, StandardSSD_LRS, or Standard_LRS."
  }
}

variable "source_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "Marketplace image reference."
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "nsg_allowed_ssh_source" {
  type        = string
  description = "Source CIDR allowed to reach port 22. Must be private, never 0.0.0.0/0 or *."
  default     = "10.0.0.0/8"

  validation {
    condition     = !contains(["*", "0.0.0.0/0", "Internet", "Any"], var.nsg_allowed_ssh_source)
    error_message = "nsg_allowed_ssh_source must be a private CIDR, not an open source."
  }
}

variable "encryption_at_host_enabled" {
  type        = bool
  description = "Encrypt temp disk and caches at the host. Requires the EncryptionAtHost feature registered on the subscription."
  default     = false
}

variable "grant_vm_key_vault_read" {
  type        = bool
  description = "Grant the VM managed identity Key Vault Secrets User on the vault. The deploying identity then needs permission to create role assignments."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
