# PostgreSQL Backup CronJobs

This setup creates automated PostgreSQL backups using Kubernetes CronJobs that execute `pgbackrest` commands in your existing PostgreSQL repository pod.

## Overview

The backup system consists of:
- **Full backups**: Every Monday at 06:00 UTC
- **Differential backups**: Tuesday through Sunday at 06:00 UTC

Jobs will fail naturally if pgbackrest returns a non-zero exit code, making them easy to monitor with Grafana or other Kubernetes monitoring systems.

## Files

- `postgres-backup-cronjobs.yaml` - CronJob definitions and RBAC setup
- `postgres-backup-cronjobs-README.md` - This documentation

## Deployment

1. **Deploy the backup CronJobs:**
   ```bash
   kubectl apply -f postgres-backup-cronjobs.yaml
   ```

2. **Verify deployment:**
   ```bash
   # Check CronJobs
   kubectl get cronjobs -n data -l app=postgres-backup
   
   # Check ServiceAccount and RBAC
   kubectl get serviceaccount postgres-backup -n data
   kubectl get role postgres-backup -n data
   kubectl get rolebinding postgres-backup -n data
   ```

## Configuration

### Target Pod Configuration
The CronJobs are configured to target:
- **Pod Name**: `cxs-pg-repo-host-0`
- **Namespace**: `data`
- **Stanza**: `db1`

To modify these values, update the ConfigMap in `postgres-backup-cronjobs.yaml`:
```yaml
data:
  backup.sh: |
    POD_NAME="your-pod-name"
    NAMESPACE="your-namespace"
    # ... rest of script
```

### Schedule Configuration
- **Full backups**: `"0 6 * * 1"` (Monday 06:00 UTC)
- **Differential backups**: `"0 6 * * 2-7"` (Tuesday-Sunday 06:00 UTC)

To change the schedule, modify the `schedule` field in the CronJob specs.

## Management Commands

### Manual Backup Execution
```bash
# Trigger a full backup manually
kubectl create job --from=cronjob/postgres-full-backup postgres-full-backup-manual -n data

# Trigger a differential backup manually
kubectl create job --from=cronjob/postgres-diff-backup postgres-diff-backup-manual -n data
```

### View Backup Status
```bash
# Check recent backup jobs
kubectl get jobs -n data -l app=postgres-backup

# View logs from the most recent backup
kubectl logs -n data -l app=postgres-backup --tail=100

# Check backup info directly from the PostgreSQL pod
kubectl exec -n data cxs-pg-repo-host-0 -- pgbackrest info --stanza=db1
```

### Cleanup Failed Jobs
```bash
# Delete failed jobs
kubectl delete jobs -n data -l app=postgres-backup --field-selector status.successful=0

# Delete all backup jobs (keeping CronJobs)
kubectl delete jobs -n data -l app=postgres-backup
```

## Troubleshooting

### Common Issues

1. **Pod not found error:**
   - Verify the pod name and namespace in the ConfigMap
   - Check if the PostgreSQL pod is running: `kubectl get pod -n data cxs-pg-repo-host-0`

2. **Permission denied:**
   - Verify the ServiceAccount, Role, and RoleBinding are properly created
   - Check if the ServiceAccount has the necessary permissions

3. **Backup command fails:**
   - Check if pgbackrest is properly configured in the target pod
   - Verify the stanza configuration
   - Check pgbackrest logs in the target pod

### View Logs
```bash
# View logs from a specific backup job
kubectl logs -n data job/postgres-full-backup-<timestamp>

# View logs from all backup jobs
kubectl logs -n data -l app=postgres-backup

# Follow logs from a running backup
kubectl logs -n data -l app=postgres-backup -f
```

### Suspend/Resume CronJobs
```bash
# Suspend all backup CronJobs
kubectl patch cronjob postgres-full-backup -n data -p '{"spec":{"suspend":true}}'
kubectl patch cronjob postgres-diff-backup -n data -p '{"spec":{"suspend":true}}'

# Resume all backup CronJobs
kubectl patch cronjob postgres-full-backup -n data -p '{"spec":{"suspend":false}}'
kubectl patch cronjob postgres-diff-backup -n data -p '{"spec":{"suspend":false}}'
```

## Monitoring with Grafana

The CronJobs are designed to fail naturally when pgbackrest returns a non-zero exit code. This makes them ideal for monitoring with Grafana using Kubernetes job metrics.

### Recommended Grafana Queries

**Job Success Rate:**
```promql
rate(kube_job_status_succeeded{namespace="data", job_name=~"postgres-.*-backup-.*"}[24h])
```

**Failed Jobs:**
```promql
kube_job_status_failed{namespace="data", job_name=~"postgres-.*-backup-.*"} > 0
```

**Job Duration:**
```promql
kube_job_status_completion_time{namespace="data", job_name=~"postgres-.*-backup-.*"} - kube_job_status_start_time{namespace="data", job_name=~"postgres-.*-backup-.*"}
```

## Security Considerations

- The ServiceAccount has minimal permissions (get, list pods and create pod/exec)
- The backup script runs in a separate pod with resource limits
- Backup jobs have timeouts to prevent hanging processes
- Failed jobs are automatically cleaned up (keeping last 3 for debugging)

## Backup Retention

The CronJob configuration keeps:
- **Full backups**: 3 successful job histories, 3 failed job histories
- **Differential backups**: 7 successful job histories, 3 failed job histories

For pgbackrest retention, configure retention policies in your pgbackrest configuration within the PostgreSQL pod. 