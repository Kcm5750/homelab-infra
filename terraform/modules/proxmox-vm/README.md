# Module: proxmox-vm

Clones a cloud-init template into one VM with a static IP, an SSH key and the
QEMU guest agent, using the `bpg/proxmox` provider.

```hcl
module "example" {
  source = "../../modules/proxmox-vm"

  name            = "lab-example"
  vm_id           = 8050
  template_vm_id  = 8001
  ipv4_address    = "10.10.10.150"
  gateway         = "10.10.10.1"
  ssh_public_keys = ["ssh-ed25519 AAAA... you@host"]
}
```

Notes:

- Disks are thin only if `datastore_id` is thin (LVM-thin, ZFS, Ceph).
  `local-lvm` is by default.
- `disk_interface` must match the template's boot disk (usually `scsi0`),
  otherwise Terraform would add a second disk instead of resizing the first.
- `protection = true` sets Proxmox's protection flag, blocking removal in the
  Proxmox UI/API. (Terraform's `prevent_destroy` cannot be set from a variable.)
- Range checks here are sanity limits. Environment-specific rules (ID range,
  reserved IDs, budget) live in the environment root.
