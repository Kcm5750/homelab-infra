# ---------------------------------------------------------------------------
# Connection (secrets come ONLY from TF_VAR_* environment variables)
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox API URL."
  type        = string
  default     = "https://10.10.10.68:8006/"

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint must start with https://."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token 'user@realm!tokenid=secret'. Set via TF_VAR_proxmox_api_token only."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@!=]+@[^!=]+![^=]+=.+$", var.proxmox_api_token))
    error_message = "proxmox_api_token must look like 'user@realm!tokenid=secret'."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (needed for Proxmox's default self-signed certificate)."
  type        = bool
  default     = false
}

variable "proxmox_ssh_username" {
  description = "Optional SSH user for provider operations that need SSH (uses your ssh-agent). null disables."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
variable "node_name" {
  description = "Proxmox node name."
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "Cloud-init template to clone."
  type        = number
  default     = 8001
}

variable "template_disk_interface" {
  description = <<-EOT
    UNCONFIRMED - verify before the first apply: interface of the boot disk of template 8001
    (Proxmox UI > VM 8001 > Hardware, e.g. "scsi0", "virtio0", "sata0").
    If it does not match, the clone gets an extra disk instead of resizing the boot disk.
  EOT
  type        = string
  default     = "scsi0"

  validation {
    condition     = can(regex("^(scsi|virtio|sata|ide)[0-9]+$", var.template_disk_interface))
    error_message = "template_disk_interface must look like scsi0, virtio0, sata0 or ide0."
  }
}

variable "datastore_id" {
  description = "Thin-provisioned datastore for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "network_cidr" {
  description = "Lab network."
  type        = string
  default     = "10.10.10.0/24"

  validation {
    condition     = can(cidrnetmask(var.network_cidr))
    error_message = "network_cidr must be a valid IPv4 CIDR."
  }
}

variable "gateway" {
  description = "Default gateway."
  type        = string
  default     = "10.10.10.1"
}

variable "ssh_public_keys" {
  description = "SSH PUBLIC keys for the cloud-init admin user (not secret). Set via TF_VAR_ssh_public_keys or tfvars."
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Provide at least one SSH public key."
  }
}

# ---------------------------------------------------------------------------
# Guard rails
# ---------------------------------------------------------------------------
variable "vm_id_range" {
  description = "Allowed VM ID range for this environment."
  type = object({
    min = number
    max = number
  })
  default = {
    min = 8000
    max = 8099
  }
}

variable "protected_vm_ids" {
  description = "VM IDs Terraform must never manage: unrelated VMs, templates, VMs managed elsewhere. Do not remove entries."
  type        = list(number)
  default     = [101, 103, 104, 8001, 8002, 9001]
}

variable "reserved_ips" {
  description = "Addresses already in use (gateway, Proxmox host, lab-app-01)."
  type        = list(string)
  default     = ["10.10.10.1", "10.10.10.68", "10.10.10.101"]
}

# >>> The ONE place to change the host budget for NEW VMs. <<<
variable "resource_budget" {
  description = "Upper bound for the SUM of all VMs defined in var.vms."
  type = object({
    max_memory_gb = number
    max_disk_gb   = number
  })
  default = {
    max_memory_gb = 20
    max_disk_gb   = 115
  }

  validation {
    condition     = var.resource_budget.max_memory_gb > 0 && var.resource_budget.max_disk_gb > 0
    error_message = "Budget values must be positive."
  }
}

# ---------------------------------------------------------------------------
# VMs. Key = VM name (hostname).
# ---------------------------------------------------------------------------
variable "vms" {
  description = "Staging VMs to create. VM 8002 (lab-app-01) is intentionally NOT here: it is Ansible-only for now."
  type = map(object({
    vm_id        = number
    ipv4_address = string
    cpu_cores    = optional(number, 2)
    memory_gb    = number
    disk_gb      = number
    groups       = optional(list(string), [])
    description  = optional(string, "Managed by Terraform (homelab-infra, staging).")
    protection   = optional(bool, false)
  }))

  default = {
    "lab-app-02" = {
      vm_id        = 8003
      ipv4_address = "10.10.10.103"
      cpu_cores    = 2
      memory_gb    = 6
      disk_gb      = 40
      groups       = ["app_servers"]
    }
    "lab-docker-01" = {
      vm_id        = 8010
      ipv4_address = "10.10.10.110"
      cpu_cores    = 4
      memory_gb    = 8
      disk_gb      = 50
      groups       = ["docker_hosts"]
    }
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : v.vm_id == floor(v.vm_id) && v.vm_id >= var.vm_id_range.min && v.vm_id <= var.vm_id_range.max])
    error_message = "Every vm_id must be an integer inside var.vm_id_range (default 8000-8099)."
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : !contains(var.protected_vm_ids, v.vm_id) && v.vm_id != var.template_vm_id])
    error_message = "A vm_id collides with a protected VM or the template (101, 103, 104, 8001, 8002, 9001 by default)."
  }

  validation {
    condition     = length(distinct([for v in values(var.vms) : v.vm_id])) == length(var.vms)
    error_message = "vm_id values must be unique."
  }

  validation {
    condition     = length(distinct([for v in values(var.vms) : v.ipv4_address])) == length(var.vms)
    error_message = "ipv4_address values must be unique."
  }

  validation {
    condition = alltrue([
      for v in values(var.vms) :
      can(cidrhost("${v.ipv4_address}/${split("/", var.network_cidr)[1]}", 0)) &&
      try(cidrhost("${v.ipv4_address}/${split("/", var.network_cidr)[1]}", 0) == cidrhost(var.network_cidr, 0), false) &&
      !contains(var.reserved_ips, v.ipv4_address)
    ])
    error_message = "Every ipv4_address must be a valid address inside var.network_cidr and not in var.reserved_ips."
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : v.cpu_cores >= 1 && v.cpu_cores <= 8 && v.cpu_cores == floor(v.cpu_cores)])
    error_message = "cpu_cores must be an integer between 1 and 8."
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : v.memory_gb >= 1 && v.memory_gb <= 16 && v.memory_gb == floor(v.memory_gb)])
    error_message = "memory_gb must be an integer between 1 and 16."
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : v.disk_gb >= 8 && v.disk_gb <= 80 && v.disk_gb == floor(v.disk_gb)])
    error_message = "disk_gb must be an integer between 8 and 80."
  }

  validation {
    condition     = alltrue([for v in values(var.vms) : alltrue([for g in v.groups : can(regex("^[a-z][a-z0-9_]*$", g))])])
    error_message = "groups must be lowercase identifiers (a-z, 0-9, _), valid as Ansible group names."
  }

  validation {
    condition     = sum([for v in values(var.vms) : v.memory_gb]) <= var.resource_budget.max_memory_gb
    error_message = "Total memory of all VMs exceeds var.resource_budget.max_memory_gb."
  }

  validation {
    condition     = sum([for v in values(var.vms) : v.disk_gb]) <= var.resource_budget.max_disk_gb
    error_message = "Total disk of all VMs exceeds var.resource_budget.max_disk_gb."
  }
}
