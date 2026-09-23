resource_group_name = "rg-app-dev"
location            = "canadacentral"

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
