# PostgreSQL Backup CronJobs

This setup creates automated PostgreSQL backups using Kubernetes CronJobs that execute `pgbackrest` commands in your existing PostgreSQL repository pod.

## Overview

The backup system consists of two repositories with staggered schedules:

### Repo1 (Local)
- **Full Backup**: Monday 06:00 UTC
- **Differential Backup**: Tuesday-Sunday 06:00 UTC

### Repo2 (MinIO)
- **Full Backup**: Tuesday 07:00 UTC  
- **Differential Backup**: Monday, Wednesday-Saturday 07:00 UTC

Jobs will fail naturally if pgbackrest returns a non-zero exit code, making them easy to monitor with Grafana or other Kubernetes monitoring systems.

## File Structure

### Core Components
- **`backup-rbac.yaml`** - ServiceAccount, Role, and RoleBinding for backup jobs
- **`backup-script-configmap.yaml`** - ConfigMap containing the backup script

### CronJob Definitions
- **`backup-cronjobs-repo1.yaml`** - Backup jobs for repo1 (local pgBackRest repository)
- **`backup-cronjobs-minio.yaml`** - Backup jobs for repo2 (MinIO S3-compatible storage)
- **`kustomization.yaml`** - Kustomize configuration for all resources

## Deployment

### Deploy All Components
```bash
# Deploy everything with kustomize
kubectl apply -k .

# Or deploy manually
kubectl apply -f backup-rbac.yaml
kubectl apply -f backup-script-configmap.yaml
kubectl apply -f backup-cronjobs-repo1.yaml
kubectl apply -f backup-cronjobs-minio.yaml
```

### Deploy Specific Repositories
```bash
# Repo1 only
kubectl apply -f backup-rbac.yaml
kubectl apply -f backup-script-configmap.yaml
kubectl apply -f backup-cronjobs-repo1.yaml

# MinIO only (requires RBAC and script to be deployed first)
kubectl apply -f backup-cronjobs-minio.yaml
```

### Verify Deployment
```bash
# Check all CronJobs
kubectl get cronjobs -n data -l app=cxs-pg-backup

# Check by repository
kubectl get cronjobs -n data -l repo=local
kubectl get cronjobs -n data -l repo=minio

# Check ServiceAccount and RBAC
kubectl get serviceaccount cxs-pg-backup -n data
kubectl get role cxs-pg-backup -n data
kubectl get rolebinding cxs-pg-backup -n data
```

## Configuration

### Target Pod Configuration
The CronJobs are configured to target:
- **Pod Name**: `cxs-pg-repo-host-0`
- **Namespace**: `data`
- **Stanza**: `db`

To modify these values, update the ConfigMap in `backup-script-configmap.yaml`:
```yaml
data:
  backup.sh: |
    POD_NAME="your-pod-name"
    NAMESPACE="your-namespace"
    # ... rest of script
```

### Repository Configuration
The backup script accepts a repository parameter:
- `$1`: Backup type (`full` or `diff`)
- `$2`: Repository number (`1` for local, `2` for MinIO)

### Schedule Configuration
**Repo1 (Local):**
- **Full backups**: `"0 6 * * 1"` (Monday 06:00 UTC)
- **Differential backups**: `"0 6 * * 0,2-6"` (Tuesday-Sunday 06:00 UTC)

**Repo2 (MinIO):**
- **Full backups**: `"0 7 * * 2"` (Tuesday 07:00 UTC)
- **Differential backups**: `"0 7 * * 1,3-6"` (Monday, Wednesday-Saturday 07:00 UTC)

To change schedules, modify the `schedule` field in the respective CronJob files.

## Management Commands

### Manual Backup Execution
```bash
# Trigger repo1 backups manually
kubectl create job --from=cronjob/cxs-pg-full-backup cxs-pg-full-backup-manual -n data
kubectl create job --from=cronjob/cxs-pg-diff-backup cxs-pg-diff-backup-manual -n data

# Trigger MinIO backups manually
kubectl create job --from=cronjob/cxs-pg-full-backup-minio cxs-pg-full-backup-minio-manual -n data
kubectl create job --from=cronjob/cxs-pg-diff-backup-minio cxs-pg-diff-backup-minio-manual -n data
```

### View Backup Status
```bash
# Check recent backup jobs
kubectl get jobs -n data -l app=postgres-backup

# Check by repository
kubectl get jobs -n data -l repo=local
kubectl get jobs -n data -l repo=minio

# View logs from the most recent backup
kubectl logs -n data -l app=postgres-backup --tail=100

# Check backup info directly from the PostgreSQL pod
kubectl exec -n data cxs-pg-repo-host-0 -- pgbackrest info --stanza=db
kubectl exec -n data cxs-pg-repo-host-0 -- pgbackrest info --stanza=db --repo=1
kubectl exec -n data cxs-pg-repo-host-0 -- pgbackrest info --stanza=db --repo=2
```

### Cleanup Failed Jobs
```bash
# Delete failed jobs
kubectl delete jobs -n data -l app=postgres-backup --field-selector status.successful=0

# Delete all backup jobs (keeping CronJobs)
kubectl delete jobs -n data -l app=postgres-backup

# Delete jobs by repository
kubectl delete jobs -n data -l repo=local
kubectl delete jobs -n data -l repo=minio
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
# Suspend repo1 backup CronJobs
kubectl patch cronjob cxs-pg-full-backup -n data -p '{"spec":{"suspend":true}}'
kubectl patch cronjob cxs-pg-diff-backup -n data -p '{"spec":{"suspend":true}}'

# Suspend MinIO backup CronJobs
kubectl patch cronjob cxs-pg-full-backup-minio -n data -p '{"spec":{"suspend":true}}'
kubectl patch cronjob cxs-pg-diff-backup-minio -n data -p '{"spec":{"suspend":true}}'

# Resume all backup CronJobs
kubectl patch cronjob cxs-pg-full-backup -n data -p '{"spec":{"suspend":false}}'
kubectl patch cronjob cxs-pg-diff-backup -n data -p '{"spec":{"suspend":false}}'
kubectl patch cronjob cxs-pg-full-backup-minio -n data -p '{"spec":{"suspend":false}}'
kubectl patch cronjob cxs-pg-diff-backup-minio -n data -p '{"spec":{"suspend":false}}'
```

## Monitoring with Grafana

The CronJobs are designed to fail naturally when pgbackrest returns a non-zero exit code. This makes them ideal for monitoring with Grafana using Kubernetes job metrics.

### Recommended Grafana Queries

**Job Success Rate:**
```promql
rate(kube_job_status_succeeded{namespace="data", job_name=~"cxs-pg-.*-backup.*"}[24h])
```

**Failed Jobs:**
```promql
kube_job_status_failed{namespace="data", job_name=~"cxs-pg-.*-backup.*"} > 0
```

**Job Duration:**
```promql
kube_job_status_completion_time{namespace="data", job_name=~"cxs-pg-.*-backup.*"} - kube_job_status_start_time{namespace="data", job_name=~"cxs-pg-.*-backup.*"}
```

**Repository-specific monitoring:**
```promql
# Repo1 success rate
rate(kube_job_status_succeeded{namespace="data", job_name=~"cxs-pg-.*-backup-[0-9]+"}[24h])

# MinIO success rate  
rate(kube_job_status_succeeded{namespace="data", job_name=~"cxs-pg-.*-backup-minio-[0-9]+"}[24h])
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