variable "name" {
  description = "VM name; also used as the guest hostname (RFC 1123 label)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.name))
    error_message = "name must be a lowercase RFC 1123 hostname label (a-z, 0-9, '-'; max 63 chars)."
  }
}

variable "vm_id" {
  description = "Proxmox VM ID. Callers apply their own, stricter range checks."
  type        = number

  validation {
    condition     = var.vm_id == floor(var.vm_id) && var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "vm_id must be an integer between 100 and 999999999."
  }
}

variable "node_name" {
  description = "Proxmox node that hosts the VM."
  type        = string
  default     = "pve"
}

variable "template_vm_id" {
  description = "VM ID of the cloud-init template to clone."
  type        = number

  validation {
    condition     = var.template_vm_id >= 100 && var.template_vm_id != var.vm_id
    error_message = "template_vm_id must be >= 100 and different from vm_id."
  }
}

variable "datastore_id" {
  description = "Datastore for the VM disk and cloud-init drive. Use a thin-provisioned store (e.g. local-lvm, ZFS)."
  type        = string
  default     = "local-lvm"
}

variable "disk_interface" {
  description = "Interface of the template's primary disk. Must match the template (usually scsi0)."
  type        = string
  default     = "scsi0"
}

variable "cpu_cores" {
  description = "Number of vCPU cores."
  type        = number
  default     = 2

  validation {
    condition     = var.cpu_cores == floor(var.cpu_cores) && var.cpu_cores >= 1 && var.cpu_cores <= 16
    error_message = "cpu_cores must be an integer between 1 and 16."
  }
}

variable "memory_mb" {
  description = "Dedicated memory in MiB."
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_mb == floor(var.memory_mb) && var.memory_mb >= 512 && var.memory_mb <= 32768
    error_message = "memory_mb must be an integer between 512 and 32768."
  }
}

variable "disk_gb" {
  description = "Size of the primary disk in GiB (cannot be shrunk later)."
  type        = number
  default     = 20

  validation {
    condition     = var.disk_gb == floor(var.disk_gb) && var.disk_gb >= 8 && var.disk_gb <= 200
    error_message = "disk_gb must be an integer between 8 and 200."
  }
}

variable "bridge" {
  description = "Linux bridge for the NIC. No VLAN tagging is used."
  type        = string
  default     = "vmbr0"
}

variable "ipv4_address" {
  description = "Static IPv4 address (without prefix length)."
  type        = string

  validation {
    condition     = can(cidrhost("${var.ipv4_address}/32", 0)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.ipv4_address))
    error_message = "ipv4_address must be a valid dotted-quad IPv4 address without a prefix length."
  }
}

variable "ipv4_prefix" {
  description = "IPv4 prefix length of the network."
  type        = number
  default     = 24

  validation {
    condition     = var.ipv4_prefix >= 8 && var.ipv4_prefix <= 30
    error_message = "ipv4_prefix must be between 8 and 30."
  }
}

variable "gateway" {
  description = "IPv4 default gateway."
  type        = string

  validation {
    condition     = can(cidrhost("${var.gateway}/32", 0))
    error_message = "gateway must be a valid IPv4 address."
  }
}

variable "dns_servers" {
  description = "DNS servers handed to the guest through cloud-init."
  type        = list(string)
  default     = ["10.10.10.1"]
}

variable "ci_username" {
  description = "Admin user created by cloud-init."
  type        = string
  default     = "ubuntu"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ci_username)) && var.ci_username != "root"
    error_message = "ci_username must be a valid Linux username and must not be root."
  }
}

variable "ssh_public_keys" {
  description = "SSH PUBLIC keys authorised for ci_username. Public keys only, never private keys."
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0 && alltrue([for k in var.ssh_public_keys : can(regex("^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp[0-9]+) ", k))])
    error_message = "ssh_public_keys must contain at least one valid OpenSSH public key."
  }
}

variable "tags" {
  description = "Proxmox tags (lowercase). Also useful for filtering in the UI."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.tags : can(regex("^[a-z0-9_-]+$", t))])
    error_message = "tags may only contain lowercase letters, digits, '_' and '-'."
  }
}

variable "description" {
  description = "VM description shown in Proxmox."
  type        = string
  default     = "Managed by Terraform (homelab-infra)."
}

variable "start_on_boot" {
  description = "Start the VM when the Proxmox node boots."
  type        = bool
  default     = true
}

variable "protection" {
  description = "Proxmox protection flag: blocks VM and disk removal in Proxmox until cleared."
  type        = bool
  default     = false
}
