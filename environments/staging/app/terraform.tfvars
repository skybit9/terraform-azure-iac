vm_name             = "vm-app-staging-001"
resource_group_name = "rg-app-staging"
location            = "canadacentral"
vm_size             = "Standard_D2s_v3"
os_disk_size_gb     = 128
os_disk_type        = "Premium_LRS"

nsg_allowed_ssh_source = "10.20.0.0/16"

# Upstream state lives in the management subscription
state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstatestaging001"

tags = {
  environment = "staging"
  stack       = "app"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
