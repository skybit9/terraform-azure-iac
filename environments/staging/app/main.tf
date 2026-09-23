# ── STACK: app (staging) ────────────────────────────────────────────────────────
# Reads networking and keyvault outputs from their state containers. The app
# pipeline identities hold Storage Blob Data READER on those two containers.

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group
    storage_account_name = var.state_storage_account
    container_name       = "tfstate-networking"
    key                  = "terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
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
    use_azuread_auth     = true
  }
}

# VMs in this stack, keyed by VM name. Add a VM: add one entry. Remove a VM:
# delete its entry; only that VM is destroyed. Never rename a key: that
# destroys the VM and creates a new one.
locals {
  vms = {
    "vm-app-staging-01" = {
      vm_size         = "Standard_D2s_v3"
      os_disk_size_gb = 128
      os_disk_type    = "Premium_LRS"
    }
  }
}

# One module call, one VM per entry in local.vms.
module "vms" {
  source   = "git::https://github.com/skybit9/terraform-azure-iac.git//modules/linux-vm?ref=v1.0.0"
  for_each = local.vms

  vm_name             = each.key
  resource_group_name = var.resource_group_name
  location            = var.location

  subnet_id    = data.terraform_remote_state.networking.outputs.app_subnet_id
  key_vault_id = data.terraform_remote_state.keyvault.outputs.key_vault_id

  vm_size                = each.value.vm_size
  os_disk_size_gb        = each.value.os_disk_size_gb
  os_disk_type           = each.value.os_disk_type
  nsg_allowed_ssh_source = var.nsg_allowed_ssh_source
  tags                   = var.tags
}
