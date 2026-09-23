# ── STACK: app (dev) ─────────────────────────────────────────────────────────
# Consumes networking and keyvault outputs via remote state. The pipeline
# identity for this stack holds Blob Data READER on those two containers only.

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group
    storage_account_name = var.state_storage_account
    container_name       = "tfstate-networking"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

data "terraform_remote_state" "keyvault" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group
    storage_account_name = var.state_storage_account
    container_name       = "tfstate-keyvault"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

module "app_vm" {
  source = "../../../modules/linux-vm"

  vm_name             = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # Wired from upstream stacks rather than hardcoded
  subnet_id    = data.terraform_remote_state.networking.outputs.app_subnet_id
  key_vault_id = data.terraform_remote_state.keyvault.outputs.key_vault_id

  vm_size                = var.vm_size
  os_disk_size_gb        = var.os_disk_size_gb
  os_disk_type           = var.os_disk_type
  nsg_allowed_ssh_source = var.nsg_allowed_ssh_source
  tags                   = var.tags
}
