# Neo4j (dev/staging/production)

## Purpose
Native graph database for highly connected data. Dev uses a single Deployment; staging/prod use a 3-replica StatefulSet with pinned enterprise image.

## Environments
- dev: single pod Deployment, `NEO4J_AUTH` from Secret `neo4j-dev-secrets`, small resources
- staging: 3-replica StatefulSet, enterprise image pinned, PDB/NetworkPolicy included
- production: 3-replica StatefulSet, enterprise image pinned, PDB/NetworkPolicy included

## Dev usage (Rancher Desktop)
```bash
cd data/neo4j
./deploy-dev.sh
./test-connection.sh
# Optional exposure:
kubectl port-forward svc/neo4j 7687:7687 -n data
```

## Secrets
- Dev: `deploy-dev.sh` creates `neo4j-dev-secrets` with `NEO4J_AUTH` from `.env`/defaults.
- Staging/Prod: manage Secrets in-cluster (Rancher/ESO later). Do not source from `.env`.

## Fleet
`fleet.yaml` targets overlays by cluster label `env=dev|staging|production`.

## Notes
- Enterprise license acceptance is provided via ConfigMap `NEO4J_ACCEPT_LICENSE_AGREEMENT=yes`.
- See `docs/k8s-standards.md` for policies and `docs/solution-version-policy.md` for image tagging.