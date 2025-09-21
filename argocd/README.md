# ArgoCD 

Argo CD is a declarative GitOps continuous delivery tool for Kubernetes that synchronizes application state from a Git repository to a cluster.

## ArgoCD Access

Authentication is via Entra ID / Microsoft SSO.

| Environment | URL |
|-------------|-----|
| **Staging** | https://argo.contextsuite.dev |
| **Production** | https://argo.contextsuite.com |


## Developer Workflow

1. **Make changes** to your workload configuration
2. **Commit and push** to main branch
3. **ArgoCD automatically deploys** within ~3 minutes
    - For the impatient: Find your Argo CD Application and hit [Refresh] or [Sync] 
4. **Monitor status** in ArgoCD UI

## Application Creation

Applications are automatically discovered and created by ArgoCD ApplicationSets that scan the repository for specific directory patterns.

### Directory Structure Pattern

ArgoCD looks for directories following this pattern:

- Staging: `<category>/*/overlays/staging`
- Production: `<category>/*/overlays/production`

where `category` can be one of 
- `apps`
- `data`
- `monitoring`
- `operators`
- `pipelines`

and generates an Argo CD Application for each where:

- **Application Name**: `{category}-{workload-name}`
- **Source Path**: `{category}/{workload-name}/overlays/{environment}`
- **Target Namespace**: Determined by the workload's kustomization.yaml
- **Sync Policy**: Automatic with self-healing enabled

### Example Applications:

```
data/postgres/overlays/staging/     → data-postgres
data/kafka/overlays/staging/        → data-kafka
monitoring/grafana/overlays/staging/ → monitoring-grafana
pipelines/airflow/overlays/staging/  → pipelines-airflow
```

## How It Works

1. **ApplicationSets** continuously scan the Git repository
2. **Discovery**: When a new `overlays/{environment}` directory is detected
3. **Creation**: ArgoCD automatically creates a new Application
4. **Deployment**: The Application syncs and deploys the service
5. **Monitoring**: ArgoCD tracks deployment status and health

## Self-Healing

ArgoCD applications are configured with **self-healing enabled**, which means:

- **Automatic drift detection**: ArgoCD continuously monitors the live cluster state vs Git
- **Automatic correction**: If someone manually modifies resources in Kubernetes (kubectl edit, etc.), ArgoCD will automatically revert changes back to what's defined in Git within 3-5 minutes
- **Configuration protection**: This prevents manual configuration drift and ensures Git remains the single source of truth
- **Override protection**: Manual "hotfixes" applied directly to the cluster will be automatically rolled back

**Important**: If you need to make emergency changes, always commit them to Git first, or temporarily disable auto-sync for that specific application in the ArgoCD UI.

---

**Migration completed**: 21/09/2025