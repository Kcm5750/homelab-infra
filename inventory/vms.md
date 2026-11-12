# Proxmox VM Inventory

Node: `pve` (10.10.10.68) · Network: 10.10.10.0/24 · Gateway: 10.10.10.1 · No VLANs

## Existing VMs

| VM ID | Name | Role | IP | Managed by | Status |
|---|---|---|---|---|---|
| 101 | Ubuntu-web | Web workloads | — | **Unmanaged — do not touch** | To verify |
| 103 | kali | Authorized security testing | — | **Unmanaged — do not touch** | To verify |
| 104 | — | Unrelated | — | **Unmanaged — do not touch** | To verify |
| 500 | Moniteering | Grafana and Prometheus monitoring | — | Unmanaged (see `docs/monitoring-recovery.md`) | Running previously |
| 8001 | cloud-init template | Cloud-init template for Terraform clones | — | Unmanaged (clone source, read-only) | Template |
| 8002 | lab-app-01 | Application workload | 10.10.10.101 | Ansible only (not in Terraform state) | To verify |
| 9001 | ubuntu-2404-template-clean | Ubuntu VM template | — | Unmanaged | Verify template status |

## Planned VMs (Terraform, `terraform/environments/staging`)

Staging VM IDs are 8000–8099. 8001 and 8002 are reserved (above).

| VM ID | Name | IP | vCPU | RAM | Disk |
|---|---|---|---|---|---|
| 8003 | lab-app-02 | 10.10.10.103 | 2 | 6 GB | 40 GB |
| 8010 | lab-docker-01 | 10.10.10.110 | 4 | 8 GB | 50 GB |

Budget for *new* VMs: ≤ ~20 GB RAM, ≤ ~115 GB thin-provisioned disk
(configured in one place: `terraform/environments/staging/variables.tf`).

## Notes

- Terraform must never import, modify or destroy VMs 101, 103 and 104.
- VM 8002 is managed by Ansible only. Importing it into Terraform is a
  later decision, after its real specs are checked.
- Confirm resource allocation and IP addresses in Proxmox.
- Never record passwords, API keys, or private keys here.
