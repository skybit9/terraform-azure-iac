resource_group_name = "rg-app-prod"
location            = "canadacentral"

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
