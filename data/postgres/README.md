# PostgreSQL

## Purpose
Provides relational database services for various applications in the project. This PostgreSQL instance is managed using the Percona PostgreSQL Operator, as indicated by the original README content.

## Configuration
- **Operator Based:** The PostgreSQL cluster is likely defined and configured via a Custom Resource (CR) managed by the Percona PostgreSQL Operator. The original README mentioned applying `cr.yaml` from the operator's GitHub repository. Specific configurations for this instance might be defined in `postgres.yaml` or through Kustomize overlays.
- **Kustomize:** `kustomization.yaml` suggests that Kustomize is used to manage environment-specific configurations or customizations for the PostgreSQL deployment.
- **Secrets:** User credentials and other sensitive information are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management. The original README mentioned a secret `cxs-pg-pguser-cxs-pg` for PGBouncer URI.

## Deployment and Management
- **Fleet:** PostgreSQL is deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet likely applies the Kustomize configurations and any Percona Operator Custom Resources.
- **Percona PostgreSQL Operator:** The operator handles the lifecycle management of the PostgreSQL cluster (provisioning, scaling, failover). The original README included steps to install the operator:
    - `kubectl create namespace postgres-operator` (though `data` namespace is used for CR)
    - `kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml -n data`
    - `kubectl apply -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/cr.yaml -n data`
- **PGBouncer:** The presence of `PGBOUNCER_URI` in the original notes indicates PGBouncer is used for connection pooling.

## Backup and Restore
- **Automated Backups:** Configured via Kubernetes CronJobs, likely defined in `backup-jobs/postgres-backup-cronjobs.yaml`.
- **Backup Strategy:** Refer to `backup-jobs/README.md` for more details on the backup strategy, tools used (e.g., pgBackRest, pg_dump), storage locations, and restoration procedures.

## Key Files
- `fleet.yaml`: Fleet configuration for PostgreSQL deployment.
- `postgres.yaml`: Potentially contains the Percona PostgreSQL Custom Resource definition or other core configurations for the cluster.
- `kustomization.yaml`: Kustomize configuration for managing PostgreSQL resources.
- `backup-jobs/`: Directory containing backup configurations.
    - `backup-jobs/README.md`: Documentation specific to backup and restore.
    - `backup-jobs/postgres-backup-cronjobs.yaml`: Kubernetes CronJob definitions for backups.
    - `backup-jobs/kustomization.yaml`: Kustomize configuration for backup jobs.
- `README.md`: This file.

## Original Notes (for reference)
The following commands were in the previous version of this README, related to operator installation and client connection:
- Operator installation commands (see Deployment section).
- PGBouncer URI retrieval: `PGBOUNCER_URI=$(kubectl get secret cxs-pg-pguser-cxs-pg --namespace data -o jsonpath='{.data.pgbouncer-uri}' | base64 --decode)`
- Client connection test: `kubectl run -i --rm --tty pg-client --image=perconalab/percona-distribution-postgresql:16 --restart=Never -- psql $PGBOUNCER_URI`
