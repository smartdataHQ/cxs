#!/bin/bash

# Show current PostgreSQL configuration

set -euo pipefail

echo "📋 PostgreSQL Configuration"
echo "========================"

# Load configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"
echo "🔧 Configuration (after .env + defaults):"
printf '  ✅ %s\n' "POSTGRES"

echo ""
echo "🔗 Connection Details:"
if [ -n "${REMOTE_POSTGRES_HOST}" ]; then
echo "  Host: ${REMOTE_POSTGRES_HOST}:${REMOTE_POSTGRES_PORT:-5432} (remote)"
echo "  User: ${REMOTE_POSTGRES_USER:-postgres}"
else
echo "  Host: postgres-dev.data.svc.cluster.local:5432 (local)"
echo "  User: postgres"
fi
echo "  Password: ${POSTGRES_PASSWORD:-${GLOBAL_ADMIN_PASSWORD:-devpassword}}"
echo ""
echo "📋 Available databases: ssp, airflow, n8n, convoy, grafana, synmetrix"