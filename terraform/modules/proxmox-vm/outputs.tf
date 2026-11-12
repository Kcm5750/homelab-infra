output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "VM name / hostname."
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  description = "Static IPv4 address configured through cloud-init."
  value       = var.ipv4_address
}

output "ssh_user" {
  description = "Admin user created by cloud-init."
  value       = var.ci_username
}

output "node_name" {
  description = "Proxmox node hosting the VM."
  value       = proxmox_virtual_environment_vm.this.node_name
}
