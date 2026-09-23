output "vm_ids" {
  description = "VM resource IDs keyed by VM name."
  value       = { for name, vm in module.vms : name => vm.vm_id }
}

output "private_ip_addresses" {
  description = "VM private IPs keyed by VM name."
  value       = { for name, vm in module.vms : name => vm.private_ip_address }
}
