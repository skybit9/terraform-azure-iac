vm_name             = "vm-app-dev-001"
resource_group_name = "rg-app-dev"
location            = "canadacentral"
vm_size             = "Standard_B2s"
os_disk_size_gb     = 64
os_disk_type        = "StandardSSD_LRS"

nsg_allowed_ssh_source = "10.10.0.0/16"

# Upstream state lives in the management subscription
state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstatedev001"

tags = {
  environment = "development"
  stack       = "app"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
