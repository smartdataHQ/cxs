# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **GitOps configuration repository** for the Quick Lookup and Context Suite Kubernetes deployment. It contains Kubernetes manifests, Helm configurations, and Kustomize overlays—not application source code. Application code lives in separate repositories and is built into Docker images pushed to Docker Hub.

**Key principle:** This repository is the single source of truth for infrastructure and application deployment configuration. All changes are managed through Git, and ArgoCD automatically synchronizes the cluster state with this repository.

## Architecture

- **GitOps Engine:** ArgoCD (replaced Fleet as of 21/09/2025)
- **Orchestration:** Kubernetes managed via Rancher
- **Package Manager:** Helm charts with Kustomize overlays
- **Image Registry:** Docker Hub (`quicklookup/*` namespace)
- **Authentication:** Tailscale VPN for cluster access
- **Monitoring:** Grafana, Victoria Metrics, Loki
- **Data Stores:** PostgreSQL, ClickHouse, Neo4j, Kafka, Redis, Solr, MinIO

## Directory Structure

```
apps/           # Application deployments (APIs, UIs, services)
data/           # Data store configurations (DBs, Kafka, etc.)
monitoring/     # Grafana, Loki, Victoria Metrics
operators/      # Cert-Manager, OpenTelemetry, MinIO, Tailscale
pipelines/      # Apache Airflow data pipelines
argocd/         # ArgoCD deployment configuration
appsets/        # ArgoCD ApplicationSet definitions
ansible/        # Bare-metal server automation
scripts/        # Operational utilities and validation
.local/         # Docker Compose for on-prem Mímir deployment
```

## Common Commands

### Kubernetes Validation

```bash
# Validate production overlays against cluster state
./scripts/validate-production.sh

# Validate staging overlays
./scripts/validate-production.sh --overlay=staging

# Validate specific apps with verbose output
./scripts/validate-production.sh --apps=contextsuite,contextapi --verbose

# Save diffs for inspection
./scripts/validate-production.sh --save-diffs --continue-on-diff

# Auto-open diff for single app (requires delta, bat, or less)
./scripts/validate-production.sh --apps=contextapi --auto-open
```

### Kustomize Testing

```bash
# Build and verify staging configuration
kubectl kustomize apps/contextsuite/overlays/staging

# Build and verify production configuration
kubectl kustomize apps/contextsuite/overlays/production

# Diff against cluster (requires cluster access)
kubectl diff -k apps/contextsuite/overlays/production
```

### On-Prem Mímir Deployment

```bash
# Start on-prem stack from project root
cp .local/mimir-onprem.env .local/.env
docker compose --project-name mimir-on-pre -f .local/docker-compose.yml up -d

# Stop stack
docker compose -f .local/docker-compose.yml down

# Stop and remove volumes
docker compose -f .local/docker-compose.yml down -v

# View logs
docker compose -f .local/docker-compose.yml logs -f <service>

# Inspect configuration
docker compose -f .local/docker-compose.yml config
```

### Database Access

```bash
# PostgreSQL port-forward and connect
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
kubectl port-forward --namespace data svc/postgresql 5432:5432 &
PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432

# Redis password
export REDIS_PASSWORD=$(kubectl get secret --namespace data redis -o jsonpath="{.data.redis-password}" | base64 -d)
```

## Application Deployment Workflow

### Standard Kustomize Structure

Each application follows this pattern:

```
app-name/
├── base/
│   ├── deployment.yaml         # NO image tags here
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml  # Image tags specified here
    │   └── config.yaml
    └── production/
        ├── kustomization.yaml  # Image tags specified here
        └── config.yaml
```

**Critical Rule:** Never specify image tags in `base/` deployments. Always use Kustomize image transformers in overlays.

### Updating Image Tags

**For staging:**
```yaml
# Edit apps/myapp/overlays/staging/kustomization.yaml
images:
  - name: quicklookup/myapp
    newTag: abc123f  # Git commit hash or tag
```

**For production:**
```yaml
# Edit apps/myapp/overlays/production/kustomization.yaml
images:
  - name: quicklookup/myapp
    newTag: v1.2.3  # Semantic version or stable tag
```

**Deploy process:**
1. Edit the overlay kustomization.yaml
2. Commit and push to main branch
3. ArgoCD auto-syncs within ~3 minutes (or manually sync in UI)

### ArgoCD Application Discovery

ArgoCD ApplicationSets automatically create Applications for any directory matching:
- `apps/*/overlays/{staging,production}`
- `data/*/overlays/{staging,production}`
- `monitoring/*/overlays/{staging,production}`
- `operators/*/overlays/{staging,production}`
- `pipelines/*/overlays/{staging,production}`

Application naming: `{category}-{workload-name}` (e.g., `apps-contextsuite`, `data-postgres`)

## Key Principles

### Security
- **No secrets in Git:** All secrets managed via Rancher or external secret managers (Vault, Keeper)
- **Tailscale VPN required** for cluster and internal resource access
- **OIDC SSO:** Entra ID for ArgoCD and on-prem Mímir deployments

### Self-Healing
ArgoCD auto-sync and self-heal are enabled. Manual kubectl changes are automatically reverted within 3-5 minutes. For emergencies, disable auto-sync in ArgoCD UI or commit changes to Git first.

### Separation of Concerns
- Application code: Separate GitHub repositories → Docker Hub images
- Deployment config: This repository → ArgoCD → Kubernetes clusters
- CI/CD: GitHub Actions builds images; this repo controls deployment

## ArgoCD Access

| Environment | URL |
|-------------|-----|
| **Staging** | https://argo.contextsuite.dev |
| **Production** | https://argo.contextsuite.com |

Authentication: Entra ID / Microsoft SSO

## Data Infrastructure

### Storage Tiers
- **Hot (local NVMe):** `/data/local/{postgres,clickhouse,neo4j,solr,keeper}`
- **Warm (elastic):** `/data/elastic/clickhouse`
- **Cold (S3):** `/data/s3/{documents,ingress}` via s3fs-fuse

### Service Endpoints (internal)
- **PostgreSQL:** `postgresql.data.svc.cluster.local:5432`
- **Redis:** `redis-master.data.svc.cluster.local:6379`
- **Kafka:** `kafka.data.svc.cluster.local:9092`
- **ClickHouse:** `clickhouse.data.svc.cluster.local:8123`
- **Neo4j:** `neo4j.data.svc.cluster.local:7687`

## On-Prem Mímir Deployment

The `.local/` directory contains a Docker Compose stack for deploying Mímir agent on-premises with minimal footprint.

**Components:** ClickHouse, Redis, cxs-services, cxs-anonymization, cxs-embeddings, mimir-server, mimir-ui, oauth2-proxy, nginx

**Prerequisites:**
- Docker Desktop or Docker Engine with Compose v2
- TLS certificates in `.local/certs/` (fullchain.pem, privkey.pem)
- Environment variables configured in `.local/.env`

**Key configuration:** All settings via environment variables. Copy `.local/mimir-onprem.env` to `.local/.env` and adjust. Mandatory: `PUBLIC_BASE_URL`, `TLS_CERTS_DIR`, `CLICKHOUSE_PASSWORD`, `REDIS_PASSWORD`, OIDC settings, LLM API keys.

## Development Workflow

1. **Branch:** Create feature branch from main
2. **Edit:** Modify Kubernetes manifests, Kustomize overlays, or Helm values
3. **Test:** `kubectl kustomize apps/myapp/overlays/staging` to verify syntax
4. **Validate:** `./scripts/validate-production.sh --apps=myapp` (if applicable)
5. **Commit:** Clear commit messages describing configuration changes
6. **PR:** Create pull request for review
7. **Merge:** ArgoCD auto-deploys within ~3 minutes of merge to main

## Ansible Infrastructure

The `ansible/` directory contains playbooks and roles for bare-metal server provisioning and monitoring setup. Used for initial cluster node preparation and system-level configuration outside Kubernetes scope.