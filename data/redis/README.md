# Redis (dev/staging/production)

## Purpose
In-memory key-value store and cache. Dev uses a single Deployment; staging/prod use a 3-node StatefulSet.

## Dev usage (Rancher Desktop)
```bash
cd data/redis
./deploy-dev.sh
./test-connection.sh
```

## Remote usage
```bash
ENABLE_REDIS=false
REMOTE_REDIS_HOST=redis.shared.dev.example.com
REMOTE_REDIS_PORT=6379
```

## Environments
- dev: single pod, IfNotPresent, small resources
- staging: 3-replica StatefulSet, PDB/NetworkPolicy, pinned tags
- production: 3-replica StatefulSet, PDB/NetworkPolicy, pinned tags

## Fleet
`fleet.yaml` targets overlays by cluster label `env=dev|staging|production`.

See also: `docs/k8s-standards.md`, `docs/solution-version-policy.md`.
