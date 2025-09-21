# Data Layer Infrastructure Monitoring

This Ansible configuration deploys comprehensive monitoring for the c001db{1:3} data layer nodes to address critical RAID-0 risks and prevent storage crises.

## Quick Start

### Deploy Monitoring
```bash
# Test connectivity
ansible data_nodes -m ping

# Deploy full monitoring stack
ansible-playbook playbooks/data-layer-monitoring.yml

# Verify deployment
ansible data_nodes -m shell -a "systemctl status node_exporter"
```

### Validate Metrics
```bash
# Check node exporter endpoints
curl http://c001db1:9100/metrics | head -20
curl http://c001db2:9100/metrics | head -20  
curl http://c001db3:9100/metrics | head -20

# Check custom metrics
curl -s http://c001db1:9100/metrics | grep -E "(smart_|minio_|loop_device_)"
```

## Architecture Overview

### Monitoring Components

1. **Node Exporter (Port 9100)**
   - System metrics (CPU, memory, network, disk I/O)
   - Process monitoring
   - Systemd service status

2. **SMART Monitoring (Every 5 minutes)**
   - NVMe drive health status
   - Temperature monitoring  
   - Wear level tracking
   - Error count monitoring
   - RAID array status

3. **MinIO Health Checks (Every minute)**
   - Service status monitoring
   - API response time tracking
   - Storage usage metrics

4. **Loop Device Monitoring (Every 2 minutes)**
   - Capacity tracking (prevents 100% storage crisis)
   - Usage percentage alerts
   - Mount status verification

### Critical Metrics

| Metric | Purpose | Alert Threshold |
|--------|---------|----------------|
| `smart_device_health` | Drive failure detection | == 0 (CRITICAL) |
| `smart_temperature_celsius` | Drive temperature | > 70°C (CRITICAL) |
| `loop_device_usage_percent` | Storage capacity | > 90% (CRITICAL) |
| `minio_service_status` | MinIO availability | == 0 (CRITICAL) |
| `up{job="data-layer-nodes"}` | Node availability | == 0 (CRITICAL) |

## Risk Mitigation

### RAID-0 Risks Addressed
- **Single Drive Failure Detection**: SMART monitoring on all 6 NVMe drives
- **Predictive Failure Alerts**: Temperature and wear level monitoring
- **Storage Capacity Crises**: Proactive alerts before reaching 100% usage
- **Service Health**: MinIO and ClickHouse availability monitoring

### Recent Storage Crisis Prevention
The monitoring stack specifically addresses the recent MinIO storage crisis:
- **Loop device capacity tracking** prevents 100% storage scenarios
- **Growth rate monitoring** enables proactive capacity planning
- **Backup operation health** ensures pgBackRest continues working

## Integration with Kubernetes

### Prometheus Configuration
Add the scrape configuration to your existing Prometheus:
```bash
kubectl apply -f ../monitoring/prometheus/data-layer-scrape-config.yml
```

### Alerting Rules  
Deploy critical alerting rules:
```bash
kubectl apply -f ../monitoring/prometheus/data-layer-alerts.yml
```

### Grafana Dashboard
Import the dashboard:
```bash
# Copy dashboard JSON to Grafana or use ConfigMap
kubectl create configmap grafana-data-layer-dashboard \
  --from-file=../monitoring/grafana/data-layer-overview-dashboard.json \
  -n monitoring
```

## Troubleshooting

### Node Exporter Issues
```bash
# Check service status
ansible data_nodes -m shell -a "systemctl status node_exporter"

# Check logs
ansible data_nodes -m shell -a "journalctl -u node_exporter -f"

# Test metrics endpoint
ansible data_nodes -m uri -a "url=http://localhost:9100/metrics"
```

### Custom Metrics Issues
```bash
# Check textfile collector
ansible data_nodes -m shell -a "ls -la /var/lib/node_exporter/textfile_collector/"

# Run SMART script manually
ansible data_nodes -m shell -a "/usr/local/bin/smart_metrics.sh"

# Check cron jobs
ansible data_nodes -m shell -a "crontab -l"
```

### SMART Monitoring Issues
```bash
# Test SMART on specific drive
ansible data_nodes -m shell -a "smartctl -H /dev/nvme0n1"

# Check available drives
ansible data_nodes -m shell -a "lsblk | grep nvme"
```

## Maintenance

### Update Node Exporter
1. Update `node_exporter_version` in `inventories/data-layer.ini`
2. Run: `ansible-playbook playbooks/data-layer-monitoring.yml`

### Add New Metrics
1. Create new script in `roles/node-exporter/templates/`
2. Add cron job in `roles/node-exporter/tasks/main.yml`
3. Deploy: `ansible-playbook playbooks/data-layer-monitoring.yml`

## Security Considerations

- Node exporter runs on port 9100 (ensure firewall allows Prometheus scraping)
- Scripts run as root for hardware access (SMART data requires root)
- SSH key authentication required for Ansible
- Metrics contain no sensitive data (hardware status only)

## Expected Outcomes

1. **Proactive Failure Detection**: Early warning before drive failures
2. **Capacity Planning**: Prevent future storage crises  
3. **Reduced MTTR**: Faster incident response with real-time visibility
4. **Risk Mitigation**: Monitor fundamental RAID-0 architecture risks