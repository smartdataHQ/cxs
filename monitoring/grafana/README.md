# Update secret

The database password is managed by the percona postgresql operator and kept in
a generated secret file. To update it you need to run the following command:

After enabling credentials towards the kubernetes cluster:

```bash
./update-db-secret.sh
```

# Alert Rules Provisioning

Alert rules are provisioned via configuration files in the `provisioning/alerting/` directory. To add or modify alert rules:

1. Edit the specific alert file in the `provisioning/alerting/` directory (e.g., `longhorn_space_alerts.yaml`)
2. Follow the Grafana alert rule format as documented in the [Grafana Alerting Provisioning documentation](https://grafana.com/docs/grafana/latest/alerting/provision-alerting-resources/)
3. Commit your changes and deploy via Fleet

