# ── STACK: app (prod) ────────────────────────────────────────────────────────
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

# One module call, any number of VMs. Adding a VM is one entry in the vms map
# in terraform.tfvars. Keyed by name, so removing one VM never disturbs another.
module "vms" {
  source   = "git::https://github.com/skybit9/terraform-azure-iac.git//modules/linux-vm?ref=v1.0.0"
  for_each = var.vms

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
