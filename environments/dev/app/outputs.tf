output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = module.app_vm.vm_id
}

output "private_ip_address" {
  description = "Private IP of the VM"
  value       = module.app_vm.private_ip_address
}
