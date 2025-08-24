#!/bin/bash

# Cleanup CXS development environment

set -euo pipefail

echo "🗑️  Cleaning up CXS Development Environment..."
echo "==========================================="

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/load-env.sh"
load_env ".env"

# Cleanup services in reverse order
echo "🚮 Cleaning up monitoring services..."
if [ "${ENABLE_PROMETHEUS:-false}" = "true" ] && [ -d "monitoring/prometheus" ] && [ -f "monitoring/prometheus/cleanup-dev.sh" ]; then
    cd monitoring/prometheus
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_LOKI:-false}" = "true" ] && [ -d "monitoring/loki" ] && [ -f "monitoring/loki/cleanup-dev.sh" ]; then
    cd monitoring/loki
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_GRAFANA:-false}" = "true" ] && [ -d "monitoring/grafana" ] && [ -f "monitoring/grafana/cleanup-dev.sh" ]; then
    cd monitoring/grafana
    ./cleanup-dev.sh
    cd ../..
fi

echo "🚮 Cleaning up application services..."
if [ "${ENABLE_INBOX:-false}" = "true" ] && [ -d "apps/inbox" ] && [ -f "apps/inbox/cleanup-dev.sh" ]; then
    cd apps/inbox
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_CXSSERVICES:-false}" = "true" ] && [ -d "apps/cxs-services" ] && [ -f "apps/cxs-services/cleanup-dev.sh" ]; then
    cd apps/cxs-services
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_CONTEXTAPI:-false}" = "true" ] && [ -d "apps/contextapi" ] && [ -f "apps/contextapi/cleanup-dev.sh" ]; then
    cd apps/contextapi
    ./cleanup-dev.sh
    cd ../..
fi

echo "🚮 Cleaning up data services..."
if [ "${ENABLE_SOLR:-false}" = "true" ] && [ -d "data/solr" ] && [ -f "data/solr/cleanup-dev.sh" ]; then
    cd data/solr
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_KAFKA:-false}" = "true" ] && [ -d "data/kafka" ] && [ -f "data/kafka/cleanup-dev.sh" ]; then
    cd data/kafka
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_NEO4J:-false}" = "true" ] && [ -d "data/neo4j" ] && [ -f "data/neo4j/cleanup-dev.sh" ]; then
    cd data/neo4j
    ./cleanup-dev.sh
    cd ../..
fi

if [ "${ENABLE_CLICKHOUSE:-false}" = "true" ] && [ -d "data/clickhouse" ] && [ -f "data/clickhouse/cleanup-dev.sh" ]; then
    cd data/clickhouse
    ./cleanup-dev.sh
    cd ../..
fi

# Always cleanup PostgreSQL since it's deployed by default
if [ -d "data/postgres" ] && [ -f "data/postgres/cleanup-dev.sh" ]; then
    echo "🚮 Cleaning up PostgreSQL..."
    cd data/postgres
    ./cleanup-dev.sh
    cd ../..
fi

echo ""
echo "✅ CXS Development Environment cleanup complete!"
echo ""
echo "📝 To redeploy:"
echo "  ./deploy-all.sh"