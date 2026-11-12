# Ansible

Configures lab VMs over SSH: hardening, Docker and node_exporter.

> **Status:** linted (`ansible-lint`, `production` profile; `yamllint --strict`) and the Jinja templates were
> rendered offline. The roles have **never been run against a real host**, and no `ansible-playbook` command has
> been executed.

## Layout

```
ansible/
├── ansible.cfg            inventory path, roles/collections paths, host key checking on
├── requirements.yml       community.general (UFW module)
├── inventory/staging/
│   ├── static.yml         hosts not created by Terraform (lab-app-01, VM 8002)
│   ├── hosts.yml          GENERATED from Terraform output, git-ignored
│   └── group_vars/        all/main.yml, all/vault.yml.example, app_servers.yml, docker_hosts.yml
├── playbooks/site.yml
├── roles/                 base_hardening, docker, node_exporter
└── examples/hosts.yml.example
```

## Roles

| Role | Hosts | Does |
|---|---|---|
| `base_hardening` | all lab hosts | SSH key-only and no root login (10-* drop-in), UFW (allow first, then default deny), unattended **security** updates, lock-out preflight |
| `node_exporter` | all lab hosts | pinned, checksum-verified release; hardened systemd unit; UFW rule; local `/metrics` check |
| `docker` | `docker_hosts` | Docker Engine + Compose plugin from the official apt repo; log rotation |

All tasks use FQCN module names, are tagged (`base`, `hardening`, `ssh`, `firewall`, `updates`, `monitoring`,
`docker`, ...), and use handlers for reloads/restarts. See each role's README.

## Secrets

Use `ansible-vault`; never put secrets in plain text.

```bash
cd ansible/inventory/staging/group_vars/all
cp vault.yml.example vault.yml && ansible-vault encrypt vault.yml     # vault.yml is git-ignored
export ANSIBLE_VAULT_PASSWORD_FILE=~/.config/homelab/vault_pass        # chmod 600, outside the repo
```

Today the only vault variable is an optional sudo password (`vault_ansible_become_password`); the default
cloud-init user has passwordless sudo, so you may not need a vault yet.

## Flagged items to confirm

- **`ansible_user` for lab-app-01 is unconfirmed.** The default is `ubuntu` (`group_vars/all/main.yml`). Override
  it in `inventory/staging/host_vars/lab-app-01.yml` once you know the real login user.
- **node_exporter is open to the whole lab network (10.10.10.0/24)** until the monitoring VM (104, "Monitering")
  IP is confirmed. TODO: set `node_exporter_allowed_sources` to that IP.
- The `sshd -t` config validation in `base_hardening` could not be tested where the roles were written.

## Running (you run these, in this order)

```bash
cd ansible
# from the repo root first: make ansible-deps   (or: ansible-galaxy collection install -r requirements.yml -p .collections)
# after Terraform has created VMs: generate hosts.yml (see terraform/README.md)
ansible-inventory --graph                                # read-only: confirms groups and hosts
ansible-playbook playbooks/site.yml --check --diff --limit lab-app-02     # dry run on ONE new host first
ansible-playbook playbooks/site.yml --limit lab-app-02                    # then apply, one host at a time
```

Run lab-app-01 (an existing VM) only after the dry run looks right: the lock-out preflight will stop the run if
the connecting user has no `authorized_keys`. The play uses `serial: 1`.
