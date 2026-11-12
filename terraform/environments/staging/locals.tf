locals {
  gateway_prefix = tonumber(split("/", var.network_cidr)[1])

  all_groups = distinct(flatten([for v in var.vms : v.groups]))

  # group name => sorted list of VM names
  ansible_groups = {
    for g in local.all_groups :
    g => sort([for name, v in var.vms : name if contains(v.groups, g)])
  }
}
