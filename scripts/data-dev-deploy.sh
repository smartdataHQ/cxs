#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/data-dev-deploy.sh [--config config/data-dev.env]
# Deploys selected data services (postgres, redis, kafka) locally using Kustomize overlays/dev.
# Requires: kubectl, kustomize, bash. For Postgres: Percona operator installed in DATA_NAMESPACE.

CONFIG_FILE="config/data-dev.env"
if [[ "${1:-}" == "--config" ]]; then
  CONFIG_FILE="${2:-$CONFIG_FILE}"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

NS="${DATA_NAMESPACE:-data}"

# Ensure namespace exists
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

echo "[info] Deploy config: POSTGRES=$ENABLE_POSTGRES REDIS=$ENABLE_REDIS KAFKA=$ENABLE_KAFKA (ns=$NS)"

# Helper to apply kustomize
kapply() {
  local path="$1"
  echo "[apply] $path"
  kubectl apply -k "$path"
}

# Postgres (Percona Operator + single-replica cluster)
if [[ "${ENABLE_POSTGRES}" == "true" ]]; then
  echo "[postgres] Installing Percona PostgreSQL Operator (if needed)"
  kubectl apply --server-side -f \
    https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml \
    -n "$NS"
  echo "[postgres] Deploying dev overlay"
  kapply "data/postgres/overlays/dev"
fi

# Redis
if [[ "${ENABLE_REDIS}" == "true" ]]; then
  echo "[redis] Deploying dev overlay"
  kapply "data/redis/overlays/dev"
fi

# Kafka
if [[ "${ENABLE_KAFKA}" == "true" ]]; then
  echo "[kafka] Deploying dev overlay"
  kapply "data/kafka/overlays/dev"
fi

echo "[done] Data dev deployment complete. Use kubectl rollout status and port-forward as needed."

