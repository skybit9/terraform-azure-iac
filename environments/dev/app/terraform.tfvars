resource_group_name = "rg-app-dev"
location            = "canadacentral"

# Add a VM: add one entry. Remove a VM: delete its entry. Others are untouched.
vms = {
  "vm-app-dev-01" = {
    vm_size         = "Standard_B2s"
    os_disk_size_gb = 64
    os_disk_type    = "StandardSSD_LRS"
  }
}

nsg_allowed_ssh_source = "10.10.0.0/16"

state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstatedev001"

tags = {
  environment = "development"
  stack       = "app"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
