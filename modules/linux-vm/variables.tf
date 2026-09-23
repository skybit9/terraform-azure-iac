# ── INPUT VARIABLES ───────────────────────────────────────────────────────────

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where all resources will be deployed"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet to attach the NIC to (no public IP, private only)"
}

variable "vm_size" {
  type        = string
  description = "Azure VM SKU size"
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the Linux VM"
  default     = "azureadmin"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB"
  default     = 128
}

variable "os_disk_type" {
  type        = string
  description = "Managed disk type for OS disk"
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be Premium_LRS, Standard_LRS, or StandardSSD_LRS."
  }
}

variable "source_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "OS image reference"
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "key_vault_id" {
  type        = string
  description = "ID of the Key Vault where the SSH public key will be stored"
}

variable "nsg_allowed_ssh_source" {
  type        = string
  description = "Source address prefix allowed to reach SSH port 22 (use private CIDR, never *)"
  default     = "10.0.0.0/8"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}
