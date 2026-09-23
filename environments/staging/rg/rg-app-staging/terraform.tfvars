resource_group_name = "rg-app-staging"
location            = "canadacentral"

nsg_allowed_ssh_source = "10.20.0.0/16"

state_resource_group  = "rg-terraform-state"
state_storage_account = "tfstatestaging001"

tags = {
  environment = "staging"
  stack       = "rg-app-staging"
  cost-center = "platform-engineering"
  owner       = "cloud-team"
  managed-by  = "terraform"
}
