# Monitoring Stack - Deployment and Recovery Runbook



## 1. Environment



- Hypervisor: Proxmox VE

- Monitoring VM ID: 500

- VM name: Moniteering

- Deployment directory: `/opt/monitoring`

- Services: Prometheus, Grafana, Proxmox VE Exporter

- Git repository: `Kcm5750/homelab-infra`



## 2. Tracked Configuration



The repository contains these monitoring configuration files:



- `monitoring/docker-compose.yml`

- `monitoring/prometheus.yml`

- `monitoring/grafana/provisioning/alerting/proxmox\_alerts.yaml`



Git stores configuration, not the persistent data held in Docker volumes.



## 3. Check Service Health



Connect to the Monitoring VM through SSH or the Proxmox console.



Run:



```bash

cd /opt/monitoring

docker compose ps

docker compose logs --tail=100

```



If a container is unhealthy or restarting, inspect its logs before making changes.



## 4. Configuration Recovery



Before replacing any configuration:



1\. Back up the existing `/opt/monitoring` directory.

2\. Obtain the repository configuration from a trusted administration machine.

3\. Review the files before transferring them to the Monitoring VM.

4\. Restore the secret `pve.yml` separately from a secure source. Never obtain it from Git.

5\. Validate the Compose configuration before applying changes.



To retrieve the repository on an administration machine:



```powershell

git clone https://github.com/Kcm5750/homelab-infra.git

cd homelab-infra

```



On the Monitoring VM, validate the existing Compose configuration:



```bash

cd /opt/monitoring

docker compose config

docker compose ps

```



Apply changes only after reviewing them and planning for possible service interruption. Verify container health and metrics after recovery.



Do not use `docker compose down -v` as a routine recovery command because it can remove persistent volumes.



## 5. Persistent Data and Backups



The monitoring stack uses these Docker volumes:



- `prom-data`: Prometheus time-series data

- `grafana-data`: Grafana persistent data



Git does not back up these volumes. Restoring configuration alone does not restore historical metrics, Grafana settings, or other persistent data.



Back up VM 500 through Proxmox. Periodically restore the backup as an isolated test VM to verify that recovery works.



Keep separate backups of any critical data that must survive VM loss.



## 6. Secrets and Access



- Never commit `pve.yml`, API tokens, passwords, or other credentials.

- Keep secret files outside Git and restrict their permissions.

- Rotate exposed API tokens and verify replacement credentials before revoking old tokens.

- A private GitHub repository is not a secret vault.



## 7. Recovery Verification



After recovery, verify the following:



- All three containers are running.

- Prometheus is scraping the Proxmox exporter and configured metric targets.

- Grafana is accessible and its Prometheus data source works.

- Dashboards and alert rules are present.

- Historical metrics are available if their data was restored.

- Any missing data or recovery issues are documented.



Record the recovery date and the actions taken.
