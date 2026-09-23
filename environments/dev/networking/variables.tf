variable "resource_group_name" {
  type        = string
  description = "Resource group for this stack"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default     = {}
}
