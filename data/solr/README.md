# Solr (dev/staging/production)

## Purpose
Search platform for the data layer. Dev uses a simple Deployment; staging/prod use SolrCloud via the operator.

## Dev usage (Rancher Desktop)
```bash
cd data/solr
./deploy-dev.sh
./test-connection.sh
./show-config.sh
# Expose locally (required for dev):
kubectl port-forward svc/solr 8983:8983 -n data
# Then open http://localhost:8983/solr
```

## Remote usage
Set in root `.env` to point to a remote Solr instead of local deploy:
```bash
ENABLE_SOLR=false
REMOTE_SOLR_HOST=solr.shared.dev.example.com
REMOTE_SOLR_PORT=8983
```

## Environments
- dev: single replica, imagePullPolicy IfNotPresent, small PVC, capped JVM
- staging: SolrCloud via operator, pinned image, resources
- production: SolrCloud via operator (3+ nodes), pinned image, resources

### Dev stability notes
- Probes are intentionally relaxed in dev to prevent restarts on slow local machines (higher timeouts/failure thresholds; longer termination grace).
- JVM defaults increased for dev to reduce OOM/restarts: `SOLR_JAVA_MEM="-Xms1g -Xmx1g"`, container requests/limits set to `1Gi/2Gi`.
- Staging and production keep stricter probes and timings. See `docs/k8s-standards.md` → Probes policy by environment.

## Fleet
`fleet.yaml` targets overlays by cluster label `env=dev|staging|production`.

See `docs/k8s-standards.md` for environment policies (probes, JVM sizing, image tags) and `docs/migration-template.md` for repo structure guidelines.

See also:
- docs/migration-template.md
- docs/k8s-standards.md
- docs/solution-version-policy.md