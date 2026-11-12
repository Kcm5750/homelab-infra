module "vm" {
  source   = "../../modules/proxmox-vm"
  for_each = var.vms

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = var.node_name
  template_vm_id = var.template_vm_id
  datastore_id   = var.datastore_id
  disk_interface = var.template_disk_interface

  cpu_cores = each.value.cpu_cores
  memory_mb = each.value.memory_gb * 1024
  disk_gb   = each.value.disk_gb

  ipv4_address = each.value.ipv4_address
  ipv4_prefix  = local.gateway_prefix
  gateway      = var.gateway

  ssh_public_keys = var.ssh_public_keys
  description     = each.value.description
  protection      = each.value.protection
  tags            = concat(["terraform", "staging"], each.value.groups)
}
