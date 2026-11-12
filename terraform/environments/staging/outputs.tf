output "vm_ids" {
  description = "VM name => Proxmox VM ID."
  value       = { for name, m in module.vm : name => m.vm_id }
}

output "ipv4_addresses" {
  description = "VM name => IPv4 address."
  value       = { for name, m in module.vm : name => m.ipv4_address }
}

output "ansible_inventory" {
  description = "Consumed by scripts/tf-to-inventory.py to build the Ansible inventory."
  value = {
    hosts = {
      for name, m in module.vm : name => {
        ansible_host = m.ipv4_address
        ansible_user = m.ssh_user
        vm_id        = m.vm_id
      }
    }
    groups = local.ansible_groups
  }
}

output "budget_summary" {
  description = "Planned resource use of the VMs managed here versus the budget."
  value = {
    memory_gb_used = sum([for v in values(var.vms) : v.memory_gb])
    memory_gb_max  = var.resource_budget.max_memory_gb
    disk_gb_used   = sum([for v in values(var.vms) : v.disk_gb])
    disk_gb_max    = var.resource_budget.max_disk_gb
  }
}
