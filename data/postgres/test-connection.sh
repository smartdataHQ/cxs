#!/bin/bash

# Test PostgreSQL connection with current configuration

set -euo pipefail

# Load configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

# Test connection
echo "🧪 Testing PostgreSQL connection..."
if [ -n "${REMOTE_POSTGRES_HOST}" ]; then
  kubectl run -i --rm --tty pg-test-$(date +%s) \
      --image=postgres:16-alpine \
      --restart=Never \
      --namespace=data \
      -- psql \
      "postgresql://${REMOTE_POSTGRES_USER:-postgres}:${REMOTE_POSTGRES_PASSWORD:-${GLOBAL_ADMIN_PASSWORD:-devpassword}}@${REMOTE_POSTGRES_HOST}:${REMOTE_POSTGRES_PORT:-5432}/postgres" \
      -c "SELECT '✅ Remote Connection OK', version();"
else
  kubectl run -i --rm --tty pg-test-$(date +%s) \
      --image=postgres:16-alpine \
      --restart=Never \
      --namespace=data \
      -- psql \
      "postgresql://postgres:${POSTGRES_PASSWORD:-${GLOBAL_ADMIN_PASSWORD:-devpassword}}@postgres-dev.data.svc.cluster.local:5432/postgres" \
      -c "SELECT '✅ Connection OK', version();"
fi