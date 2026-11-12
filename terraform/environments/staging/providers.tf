provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Only needed for operations the Proxmox API cannot do (e.g. uploading
  # snippets). Leave proxmox_ssh_username unset unless an apply asks for it.
  dynamic "ssh" {
    for_each = var.proxmox_ssh_username == null ? [] : [var.proxmox_ssh_username]
    content {
      agent    = true
      username = ssh.value
    }
  }
}
