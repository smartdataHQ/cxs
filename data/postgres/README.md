# PostgreSQL (dev/staging/production)

## Purpose
Relational database for platform solutions. Dev uses the official Postgres image with simple K8s resources; staging/production scale via overlays and Fleet.

## Architecture and decisions
- Dev: standard `postgres:16-alpine`, no operators (simpler, ARM64-friendly)
- Base manifests are environment-agnostic (`postgres`, `postgres-pvc`, `postgres-config`, `postgres-init`)
- Overlays set replicas/resources/storage and image pull policy
- Secrets managed via cluster for staging/prod; dev uses script-created Secret `postgres-secrets`

## Layout
```
base/
  postgres-simple.yaml        # Deployment/Service/PVC/ConfigMaps
overlays/
  dev/                        # 1 replica, small resources, 5Gi, Never pull
  staging/                    # 2 replicas, medium resources, 20Gi
  production/                 # 3 replicas, limits, 50Gi
fleet*.yaml                   # env targeting
deploy-dev.sh | cleanup-dev.sh | test-connection.sh | show-config.sh
```

## Dev usage (Rancher Desktop)
```bash
cd data/postgres
./deploy-dev.sh
./test-connection.sh
```

## Remote usage
Set in root `.env` to use a remote DB instead of local deploy:
```bash
ENABLE_POSTGRES=false
REMOTE_POSTGRES_HOST=db.dev.example.com
REMOTE_POSTGRES_PORT=5432
REMOTE_POSTGRES_USER=postgres
REMOTE_POSTGRES_PASSWORD=changeme
```

## Staging/Production
Fleet `targetCustomizations` select the appropriate overlay by cluster label. Use pinned image tags, requests/limits, TLS, and managed secrets.

> WARNING: The production overlay in this repo is not HA and should not be used as-is in production. Per policy (see `docs/k8s-standards.md` → Data layer HA policy), production requires a highly available Postgres (operator or managed service) with a minimum of 3 nodes. Consider CrunchyData, Zalando Postgres Operator, or a managed cloud Postgres.
