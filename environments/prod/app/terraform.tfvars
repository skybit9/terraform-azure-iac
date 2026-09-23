resource_group_name = "rg-app-prod"
location            = "canadacentral"

# Add a VM: add one entry. Remove a VM: delete its entry. Others are untouched.
vms = {
  "vm-app-prod-01" = {
    vm_size         = "Standard_D4s_v3"
    os_disk_size_gb = 128
    os_disk_type    = "Premium_LRS"
  }
}

nsg_allowed_ssh_source = "10.30.0.0/16"

state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstateprod001"

tags = {
  environment = "production"
  stack       = "app"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
