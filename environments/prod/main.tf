# ── ROOT MODULE: prod ───────────────────────────────────────────────────────────
# Pin the module to a released tag. Promote by bumping the ref:
# dev first, then staging, then prod.

module "app_vm" {
  source = "../../modules/linux-vm"

  vm_name             = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  key_vault_id        = var.key_vault_id
  vm_size             = var.vm_size
  tags                = var.tags
}
