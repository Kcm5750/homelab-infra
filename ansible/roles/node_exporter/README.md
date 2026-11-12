# node_exporter

Installs a pinned Prometheus `node_exporter` release (SHA-256 verified) under `/opt/node_exporter/<version>/`,
symlinks `/usr/local/bin/node_exporter`, runs it as an unprivileged `node_exporter` user in a hardened systemd
unit, opens UFW port 9100 for `node_exporter_allowed_sources`, and checks `/metrics` answers locally.

Tags: `monitoring`, `node_exporter`, `node_exporter_install`, `node_exporter_config`, `node_exporter_firewall`,
`node_exporter_verify`.

**Upgrading:** change `node_exporter_version` and update `node_exporter_checksums` from the release's
`sha256sums.txt` (verify it on the release page).

**Scraping** (add to `monitoring/prometheus.yml` on the monitoring VM, then review and redeploy):

```yaml
  - job_name: 'node'
    static_configs:
      - targets: ['10.10.10.101:9100', '10.10.10.103:9100', '10.10.10.110:9100']
```

Narrow `node_exporter_allowed_sources` to the monitoring VM's address once confirmed.
