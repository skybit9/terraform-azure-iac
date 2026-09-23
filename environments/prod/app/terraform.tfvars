vm_name             = "vm-app-prod-001"
resource_group_name = "rg-app-prod"
location            = "canadacentral"
vm_size             = "Standard_D4s_v3"
os_disk_size_gb     = 128
os_disk_type        = "Premium_LRS"

nsg_allowed_ssh_source = "10.30.0.0/16"

# Upstream state lives in the management subscription
state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstateprod001"

tags = {
  environment = "production"
  stack       = "app"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
