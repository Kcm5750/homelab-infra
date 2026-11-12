# docker

Installs Docker Engine, containerd, Buildx and the Compose plugin from Docker's official apt repository
(signed-by keyring, no `apt_key`) and writes `/etc/docker/daemon.json` (log rotation, live-restore).

Tags: `docker`, `docker_install`, `docker_config`, `docker_users`.

Variables: see `defaults/main.yml`. Notable: `docker_users` (docker group = root-equivalent),
`docker_daemon_config`, `docker_remove_conflicting` (opt-in), `docker_apt_key_checksum` (optional pin).

## Docker and UFW

Docker publishes container ports by editing iptables directly, **so `-p 8080:80` is reachable even when UFW
denies it**. Mitigate by binding to localhost (`-p 127.0.0.1:8080:80`) or a specific address, and putting a
reverse proxy in front. Do not rely on UFW rules to hide published container ports.
