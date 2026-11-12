# Terraform

Provisions staging VMs on the Proxmox node `pve` by cloning the cloud-init template (VM 8001), using the
[`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) provider.

> **Status:** formatted, validated and linted (`terraform fmt`, `terraform validate`, `tflint`).
> `terraform plan` / `apply` have **not** been run against the real Proxmox server.

## Layout

```
terraform/
├── modules/proxmox-vm/        reusable module: one cloud-init VM (typed + validated inputs)
└── environments/staging/      the root module you run commands in
    ├── versions.tf            required_version >= 1.9, bpg/proxmox ~> 0.122.0 (lock file committed)
    ├── backend.tf             local state (see "State")
    ├── providers.tf           provider config; token comes from the environment
    ├── variables.tf           typed variables + guard rails (ID range, protected IDs, IPs, budget)
    ├── locals.tf / main.tf    Ansible groups, and one module call per VM in var.vms
    ├── outputs.tf             vm_ids, ipv4_addresses, ansible_inventory, budget_summary
    └── terraform.tfvars.example
```

## Secrets

Secrets are **only** passed as environment variables. Real `*.tfvars` files are git-ignored; there is no real
tfvars file in this repo.

| Variable | Purpose |
|---|---|
| `TF_VAR_proxmox_api_token` | Proxmox API token (`user@realm!tokenid=secret`); marked `sensitive` |
| `TF_VAR_ssh_public_keys` | JSON list of SSH **public** keys for the cloud-init user (not secret) |

## Guard rails (`environments/staging/variables.tf`)

- `vm_id` must be in 8000-8099 and unique, and must not be a protected ID
  (`protected_vm_ids`: 101, 103, 104, 8001, 8002, 9001) or the template ID.
- IPs must be unique, inside `network_cidr` and not in `reserved_ips` (gateway, Proxmox host, lab-app-01).
- Per VM: 1-8 vCPU, 1-16 GB RAM, 8-80 GB disk.
- **Budget** for the VMs defined here: `resource_budget` (default 20 GB RAM / 115 GB disk), the one place to
  change it. The default VM set uses 14 GB RAM and 90 GB disk. VM 8002 is not counted (it is not managed here).
- `template_disk_interface` (default `scsi0`) is **unconfirmed**: check template 8001's boot disk in the Proxmox
  UI before the first apply, or Terraform would add a second disk instead of resizing the first.

## Running

Checks (no server contact): from the repo root, `make check` (see the root README).

A plan is something **you** run, after reading the code. Nothing in this repo runs `apply` for you.

```bash
cd terraform/environments/staging
export TF_VAR_proxmox_api_token='<your token>'          # never commit or paste this anywhere
export TF_VAR_ssh_public_keys='["ssh-ed25519 AAAA... you@host"]'
# optional: copy terraform.tfvars.example to terraform.tfvars (git-ignored) to override defaults
terraform init
terraform plan          # read it fully: it must only create the VMs you expect
# terraform apply       # deliberate, manual step, only after the plan looks right
```

Self-signed Proxmox certificate? Set `proxmox_insecure = true` (see the example file).

## State

Local state (`terraform.tfstate`, git-ignored, may contain sensitive values), protected by an **encrypted backup
outside WSL** rather than a remote backend.

- `scripts/tfstate-backup.sh`: tars the state, encrypts it with [`age`](https://github.com/FiloSottile/age)
  using a **public** key, verifies the copy by checksum, keeps the newest N (default 30). It refuses
  destinations inside the repo or on WSL's own filesystem.
- `scripts/tfstate-restore.sh`: decrypts with your private key, verifies the checksum, refuses to overwrite
  existing state without `--force` (and then keeps the old file).

```bash
age-keygen -o age-key.txt        # keep age-key.txt OFFLINE (password manager / USB), never in this repo or WSL
export TFSTATE_AGE_RECIPIENT='age1...'                          # the PUBLIC key printed by age-keygen
export TFSTATE_BACKUP_DEST='/mnt/c/Users/<you>/Backups/homelab-tfstate'
scripts/tfstate-backup.sh        # run after every apply (not scheduled automatically)

# Restore (e.g. after losing the WSL install):
AGE_IDENTITY_FILE=/path/to/age-key.txt scripts/tfstate-restore.sh /mnt/c/.../tfstate-staging-<timestamp>.tar.gz.age
cd terraform/environments/staging && terraform init && terraform plan   # should show no unexpected changes
```

Not chosen, but possible later (`terraform init -migrate-state`): an S3-compatible backend such as MinIO
(locking, but another service to run and back up), or HCP Terraform (managed, but state leaves the lab).

## VM 8002 (lab-app-01)

Intentionally **not** in Terraform. It is configured by Ansible only; importing it is a later decision, after its
real specs are checked.

## Ansible inventory

`terraform output -json ansible_inventory | ../../../scripts/tf-to-inventory.py` writes the git-ignored
`ansible/inventory/staging/hosts.yml`. See [`../ansible/README.md`](../ansible/README.md).
