# Migration to new k8s cluster

### Namespaces we shouldn't migrate

#### Empty namespaces _(no resources)_
- cattle-dashboards
- cattle-impersonation-system
- kafka
- local
- openobserve
- openobserve-collector
- opentelemetry-operator-system
- tom
- tommi
- vault
- vector

### Unclear stuff

#### Minio
We have definition for MinIO stored in:

- `data/c00dbmappings/overlays/production/minio.yaml`

and I can't find any pods, services, etc.  there is no `storage` namespace also.