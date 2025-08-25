# ClickHouse (dev/staging/production)

## Purpose
Columnar OLAP database. Dev uses a single Deployment; staging/prod use a 3-replica StatefulSet.

## Dev usage (Rancher Desktop)
```bash
cd data/clickhouse
./deploy-dev.sh
./test-connection.sh
# Expose locally if needed:
kubectl port-forward svc/clickhouse 8123:8123 -n data
```

## Remote usage
```bash
ENABLE_CLICKHOUSE=false
REMOTE_CLICKHOUSE_HOST=clickhouse.shared.dev.example.com
REMOTE_CLICKHOUSE_HTTP_PORT=8123
```

## Environments
- dev: single pod Deployment, IfNotPresent, small resources
- staging: 3-replica StatefulSet, medium resources
- production: 3-replica StatefulSet, policies/config, pinned image

## Fleet
`fleet.yaml` targets overlays by cluster label `env=dev|staging|production`.

See also:
- docs/migration-template.md
- docs/k8s-standards.md
- docs/solution-version-policy.md
