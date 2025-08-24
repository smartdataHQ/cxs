#!/bin/bash

# PostgreSQL Development Deployment
# Single script to deploy PostgreSQL with sane defaults

set -euo pipefail

echo "🚀 PostgreSQL Development Setup"
echo "=============================="

# 1. Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl required. Install kubectl first."
    exit 1
fi

# 2. Load configuration (or use defaults)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    echo "📄 Loading root .env configuration..."
fi
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

# Service-local defaults (overridable via local .env)
: "${ENABLE_POSTGRES:=true}"
: "${ENABLE_PGADMIN:=false}"
: "${ENABLE_MONITORING:=false}"
: "${POSTGRES_PASSWORD:=${GLOBAL_ADMIN_PASSWORD:-devpassword}}"
: "${APP_PASSWORD:=${GLOBAL_APP_PASSWORD:-devpassword}}"

# 3. Show what will be deployed
echo ""
echo "🔧 Services to deploy:"
[ "${ENABLE_POSTGRES:-true}" = "true" ] && echo "  ✅ PostgreSQL" || echo "  ❌ PostgreSQL (skipped)"
[ "${ENABLE_PGADMIN:-false}" = "true" ] && echo "  ✅ PgAdmin" || echo "  ❌ PgAdmin (skipped)"
[ "${ENABLE_MONITORING:-false}" = "true" ] && echo "  ✅ Monitoring" || echo "  ❌ Monitoring (skipped)"
echo ""

# 4. Create namespace
echo "📁 Setting up namespace..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

# 5. Create secrets with passwords
echo "🔐 Setting up secrets..."
kubectl create secret generic postgres-secrets \
  --namespace=data \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --from-literal=CXS_PG_PASSWORD="${APP_PASSWORD}" \
  --from-literal=AIRFLOW_DB_PASSWORD="${APP_PASSWORD}" \
  --from-literal=N8N_DB_PASSWORD="${APP_PASSWORD}" \
  --from-literal=CONVOY_DB_PASSWORD="${APP_PASSWORD}" \
  --from-literal=GRAFANA_DB_PASSWORD="${APP_PASSWORD}" \
  --from-literal=SYNMETRIX_PASSWORD="${APP_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. Base ConfigMaps are part of kustomize. No dynamic ConfigMap creation here.

# 7. Deploy PostgreSQL locally if not using remote
if [ -z "${REMOTE_POSTGRES_HOST}" ] && [ "${ENABLE_POSTGRES:-true}" = "true" ]; then
    echo "🚢 Deploying PostgreSQL..."
    kubectl apply -k overlays/dev
    echo "⏳ Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres-dev -n data
else
    echo "⏭️  PostgreSQL local deployment skipped (remote configured or disabled)"
fi

# 8. Deploy optional services
if [ "${ENABLE_PGADMIN:-false}" = "true" ]; then
    echo "🚢 Deploying PgAdmin..."
    # Future: kubectl apply -f pgadmin/
    echo "⚠️  PgAdmin deployment not yet implemented"
fi

if [ "${ENABLE_MONITORING:-false}" = "true" ]; then
    echo "🚢 Deploying monitoring..."
    # Future: kubectl apply -f monitoring/
    echo "⚠️  Monitoring deployment not yet implemented"
fi

# 9. Show connection info
echo ""
echo "✅ PostgreSQL setup complete!"
echo ""
echo "🔗 Connection Information:"
if [ -n "${REMOTE_POSTGRES_HOST}" ]; then
echo "  Host: ${REMOTE_POSTGRES_HOST}:${REMOTE_POSTGRES_PORT:-5432} (remote)"
echo "  User: ${REMOTE_POSTGRES_USER:-postgres}"
echo "  Password: ${REMOTE_POSTGRES_PASSWORD:-${GLOBAL_ADMIN_PASSWORD:-devpassword}}"
else
echo "  Host: postgres-dev.data.svc.cluster.local:5432 (local)"
echo "  User: postgres"
echo "  Password: ${POSTGRES_PASSWORD:-devpassword}"
fi
echo ""
echo "📋 Available databases: ssp, airflow, n8n, convoy, grafana, synmetrix"
echo "🧪 Test connection: ./test-connection.sh"
echo "📊 View config: ./show-config.sh"
echo "🗑️  Cleanup: ./cleanup-dev.sh"