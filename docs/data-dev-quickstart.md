# Data Namespace: Dev Quickstart (Postgres, Redis, Kafka)

This guide helps you spin up just the data services you need on your local Kubernetes (Rancher Desktop/Rancher-managed dev cluster). The goal is minimal resource usage with single-instance, dev-friendly overlays.

## Prerequisites
- Rancher Desktop with Kubernetes and containerd enabled
- kubectl and kustomize (or `kubectl kustomize`)
- Namespace `data` (create if missing):
  ```bash
  kubectl get ns data || kubectl create ns data
  ```


## One-command deploy (recommended)
Use the toggleable config and script to deploy only what you need:

1) Review and edit config/data-dev.env:
```
ENABLE_POSTGRES=true
ENABLE_REDIS=true
ENABLE_KAFKA=true
DATA_NAMESPACE=data
```

2) Run the deploy script:
```
scripts/data-dev-deploy.sh --config config/data-dev.env
```

You can override the config file path or edit ENABLE_* flags to cherry-pick components. The script ensures the namespace exists, installs the Percona PostgreSQL Operator if needed, and applies the Kustomize dev overlays for selected services.

## General tips
- Only deploy what you need; almost no developer needs the full data stack locally.
- Prefer port-forwarding over ingress for data services in dev.
- Secrets: continue to use Rancher-managed Secret names/keys. For local dev, create placeholders:
  ```bash
  make dev-secrets NAMESPACE=data NAME=<secret-name> FILE=.env.local
  ```
- Cleanup when done:
  ```bash
  kubectl delete -k data/<component>/overlays/dev
  ```

---

## Redis (dev)
Deploy:
```bash
kustomize build data/redis/overlays/dev | kubectl apply -f -
```
Verify:
```bash
kubectl -n data get deploy,svc | grep redis
kubectl -n data rollout status deploy/redis
```
Port-forward (optional):
```bash
kubectl -n data port-forward svc/redis 6379:6379
```

---

## Kafka (dev)
Deploy single-broker KRaft Kafka:
```bash
kustomize build data/kafka/overlays/dev | kubectl apply -f -
```
Verify:
```bash
kubectl -n data get deploy,svc | grep kafka
kubectl -n data rollout status deploy/kafka
```
Port-forward (optional):
```bash
kubectl -n data port-forward svc/kafka 9092:9092
```

---

## PostgreSQL (dev)
This repo uses the Percona PostgreSQL Operator for PostgreSQL. For dev, we run a single-replica cluster with small volumes.

1) Install the operator (one-time per cluster):
```bash
# Install operator bundle into the data namespace
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml \
  -n data
```

2) Deploy the dev overlay:
```bash
kustomize build data/postgres/overlays/dev | kubectl apply -f -
```

3) Verify:
```bash
kubectl -n data get perconapgclusters.pgv2.percona.com
kubectl -n data get pods -l postgres-operator.crunchydata.com/cluster=cxs-pg
```

4) Connect (port-forward via pgBouncer if present):
```bash
# Service names may vary by operator version; common names shown:
kubectl -n data get svc | grep cxs-pg
# Example port-forward:
kubectl -n data port-forward svc/cxs-pg-pgbouncer 5432:5432
```

Cleanup:
```bash
kubectl delete -k data/postgres/overlays/dev
```

---

## Troubleshooting
- If `kustomize` is not installed, use `kubectl apply -k <path>`.
- If pods are Pending due to storage, switch to emptyDir or a local-path provisioner in the dev overlay (open an issue and we’ll add it).
- If the Percona operator isn’t ready, wait for the operator pod(s) to be Running before applying the CR.

## Notes
- High availability is not applicable for developer machines; dev overlays minimize replicas/resources.
- Staging and production use HA topologies and operators (Kafka via Strimzi, Postgres via Percona, etc.).

