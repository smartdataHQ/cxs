#!/bin/bash

# CXS Development Environment Deployment
# Single script to deploy selected services with sane defaults

set -euo pipefail

echo "🚀 CXS Development Environment Setup"
echo "==================================="

# 1. Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl required. Install kubectl first."
    exit 1
fi

# 2. Load configuration (or use defaults)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f ".env" ]; then
    echo "📄 Loading .env configuration..."
fi
source "$SCRIPT_DIR/scripts/lib/load-env.sh"
load_env ".env"

# 3. Show what will be deployed
echo ""
echo "🔧 Services to deploy:"
if [ -n "${REMOTE_POSTGRES_HOST}" ]; then
    echo "  🔗 PostgreSQL (remote: ${REMOTE_POSTGRES_HOST}:${REMOTE_POSTGRES_PORT})"
else
    [ "${ENABLE_POSTGRES:-false}" = "true" ] && echo "  ✅ PostgreSQL" || echo "  ❌ PostgreSQL (skipped)"
fi
[ "${ENABLE_CLICKHOUSE:-false}" = "true" ] && echo "  ✅ ClickHouse" || echo "  ❌ ClickHouse (skipped)"
[ "${ENABLE_NEO4J:-false}" = "true" ] && echo "  ✅ Neo4j" || echo "  ❌ Neo4j (skipped)"
if [ -n "${REMOTE_KAFKA_HOST:-}" ] || [ -n "${REMOTE_KAFKA_BROKERS:-}" ]; then
    echo "  🔗 Kafka (remote: ${REMOTE_KAFKA_HOST:-${REMOTE_KAFKA_BROKERS}})"
else
    [ "${ENABLE_KAFKA:-false}" = "true" ] && echo "  ✅ Kafka" || echo "  ❌ Kafka (skipped)"
fi
if [ -n "${REMOTE_SOLR_HOST:-}" ]; then
    echo "  🔗 Solr (remote: ${REMOTE_SOLR_HOST}:${REMOTE_SOLR_PORT})"
else
    [ "${ENABLE_SOLR:-false}" = "true" ] && echo "  ✅ Solr" || echo "  ❌ Solr (skipped)"
fi
[ "${ENABLE_REDIS:-false}" = "true" ] && echo "  ✅ Redis" || echo "  ❌ Redis (skipped)"
[ "${ENABLE_CONTEXTAPI:-false}" = "true" ] && echo "  ✅ Context API" || echo "  ❌ Context API (skipped)"
[ "${ENABLE_CXSSERVICES:-false}" = "true" ] && echo "  ✅ CXS Services" || echo "  ❌ CXS Services (skipped)"
[ "${ENABLE_INBOX:-false}" = "true" ] && echo "  ✅ Inbox" || echo "  ❌ Inbox (skipped)"
[ "${ENABLE_GRAFANA:-false}" = "true" ] && echo "  ✅ Grafana" || echo "  ❌ Grafana (skipped)"
[ "${ENABLE_LOKI:-false}" = "true" ] && echo "  ✅ Loki" || echo "  ❌ Loki (skipped)"
[ "${ENABLE_PROMETHEUS:-false}" = "true" ] && echo "  ✅ Prometheus" || echo "  ❌ Prometheus (skipped)"
echo ""

# 4. Deploy services
echo "🚢 Deploying selected services..."
echo ""

# Deploy data services first (dependencies)
if [ -z "${REMOTE_POSTGRES_HOST}" ] && [ "${ENABLE_POSTGRES:-false}" = "true" ]; then
    if [ -d "data/postgres" ] && [ -f "data/postgres/deploy-dev.sh" ]; then
        echo "📦 Deploying PostgreSQL..."
        cd data/postgres
        # Pass passwords to individual service
        POSTGRES_PASSWORD="${GLOBAL_ADMIN_PASSWORD:-devpassword}" \
        APP_PASSWORD="${GLOBAL_APP_PASSWORD:-devpassword}" \
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  PostgreSQL not found or not migrated yet"
    fi
fi

if [ "${ENABLE_CLICKHOUSE:-false}" = "true" ]; then
    if [ -d "data/clickhouse" ] && [ -f "data/clickhouse/deploy-dev.sh" ]; then
        echo "📦 Deploying ClickHouse..."
        cd data/clickhouse
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  ClickHouse not found or not migrated yet"
    fi
fi

if [ "${ENABLE_NEO4J:-false}" = "true" ]; then
    if [ -d "data/neo4j" ] && [ -f "data/neo4j/deploy-dev.sh" ]; then
        echo "📦 Deploying Neo4j..."
        cd data/neo4j
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Neo4j not found or not migrated yet"
    fi
fi

if [ -z "${REMOTE_KAFKA_HOST:-}" ] && [ -z "${REMOTE_KAFKA_BROKERS:-}" ] && [ "${ENABLE_KAFKA:-false}" = "true" ]; then
    if [ -d "data/kafka" ] && [ -f "data/kafka/deploy-dev.sh" ]; then
        echo "📦 Deploying Kafka..."
        cd data/kafka
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Kafka not found or not migrated yet"
    fi
elif [ -n "${REMOTE_KAFKA_HOST:-}" ] || [ -n "${REMOTE_KAFKA_BROKERS:-}" ]; then
    echo "⏭️  Skipping Kafka deploy (remote configured)"
fi

if [ -z "${REMOTE_SOLR_HOST:-}" ] && [ "${ENABLE_SOLR:-false}" = "true" ]; then
    if [ -d "data/solr" ] && [ -f "data/solr/deploy-dev.sh" ]; then
        echo "📦 Deploying Solr..."
        cd data/solr
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Solr not found or not migrated yet"
    fi
elif [ -n "${REMOTE_SOLR_HOST:-}" ]; then
    echo "⏭️  Skipping Solr deploy (remote configured)"
fi

if [ "${ENABLE_REDIS:-false}" = "true" ]; then
    if [ -d "data/redis" ] && [ -f "data/redis/deploy-dev.sh" ]; then
        echo "📦 Deploying Redis..."
        cd data/redis
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Redis not found or not migrated yet"
    fi
fi

# Deploy application services
if [ "${ENABLE_CONTEXTAPI:-false}" = "true" ]; then
    if [ -d "apps/contextapi" ] && [ -f "apps/contextapi/deploy-dev.sh" ]; then
        echo "📱 Deploying Context API..."
        cd apps/contextapi
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Context API not found or not migrated yet"
    fi
fi

if [ "${ENABLE_CXSSERVICES:-false}" = "true" ]; then
    if [ -d "apps/cxs-services" ] && [ -f "apps/cxs-services/deploy-dev.sh" ]; then
        echo "📱 Deploying CXS Services..."
        cd apps/cxs-services
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  CXS Services not found or not migrated yet"
    fi
fi

if [ "${ENABLE_INBOX:-false}" = "true" ]; then
    if [ -d "apps/inbox" ] && [ -f "apps/inbox/deploy-dev.sh" ]; then
        echo "📱 Deploying Inbox..."
        cd apps/inbox
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Inbox not found or not migrated yet"
    fi
fi

# Deploy monitoring services
if [ "${ENABLE_GRAFANA:-false}" = "true" ]; then
    if [ -d "monitoring/grafana" ] && [ -f "monitoring/grafana/deploy-dev.sh" ]; then
        echo "📊 Deploying Grafana..."
        cd monitoring/grafana
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Grafana not found or not migrated yet"
    fi
fi

if [ "${ENABLE_LOKI:-false}" = "true" ]; then
    if [ -d "monitoring/loki" ] && [ -f "monitoring/loki/deploy-dev.sh" ]; then
        echo "📊 Deploying Loki..."
        cd monitoring/loki
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Loki not found or not migrated yet"
    fi
fi

if [ "${ENABLE_PROMETHEUS:-false}" = "true" ]; then
    if [ -d "monitoring/prometheus" ] && [ -f "monitoring/prometheus/deploy-dev.sh" ]; then
        echo "📊 Deploying Prometheus..."
        cd monitoring/prometheus
        ./deploy-dev.sh
        cd ../..
        echo ""
    else
        echo "⚠️  Prometheus not found or not migrated yet"
    fi
fi

# 5. Post-deploy checks
if [ -f "$SCRIPT_DIR/test-connections.sh" ]; then
  echo "🧪 Running aggregated connection tests..."
  "$SCRIPT_DIR/test-connections.sh"
fi

# 6. Show summary
echo "✅ CXS Development Environment Setup Complete!"
echo ""
echo "📋 Next steps:"
echo "  ./show-config.sh     - View current configuration"
echo "  ./test-connections.sh - Test service connections"
echo "  ./cleanup-all.sh     - Remove all deployments"
echo ""
echo "📝 Individual service management:"
echo "  cd data/postgres && ./deploy-dev.sh    - Manage PostgreSQL"
echo "  cd apps/contextapi && ./deploy-dev.sh  - Manage Context API"