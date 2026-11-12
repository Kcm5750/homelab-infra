# base_hardening

Target: Ubuntu 24.04 (Debian family). Tags: `base`, `hardening`, plus `preflight`, `ssh`, `firewall`, `updates`.

| Area | What it does |
|---|---|
| SSH | `/etc/ssh/sshd_config.d/10-hardening.conf`: no root login, keys only, no passwords, limited auth tries. Validated with `sshd -t` before it is written, then reloaded. |
| Firewall | UFW: allow SSH (and extra rules) first, then default deny incoming, then enable. |
| Updates | `unattended-upgrades`, security pockets only, no automatic reboot by default. |

**Lock-out preflight** (`tasks/preflight.yml`) aborts before touching SSH if you connect as root, if the
connecting user has no `~/.ssh/authorized_keys`, or if no SSH source CIDR is configured.

Key variables (see `defaults/main.yml`): `base_hardening_ssh_allowed_cidrs`,
`base_hardening_firewall_extra_rules`, `base_hardening_unattended_upgrades_reboot`.

Caveats:

- Docker-published ports bypass UFW (see the `docker` role).
- The `sshd -t` validation could not be tested in the authoring environment (no sshd available); check it with
  `--check --diff` against one host first.
