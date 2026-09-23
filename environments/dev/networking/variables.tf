variable "resource_group_name" {
  type        = string
  description = "Resource group for this stack. Created by bootstrap/03-rbac.sh."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
