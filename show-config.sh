#!/bin/bash

# Show current CXS development environment configuration

set -euo pipefail

echo "📋 CXS Development Environment Configuration"
echo "=========================================="

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/load-env.sh"
load_env ".env"
echo "🔧 Configuration (after .env + defaults):"
    
    # Show enabled data services
    echo "  Data Services:"
    if [ -n "${REMOTE_POSTGRES_HOST}" ]; then
        echo "    🔗 PostgreSQL (remote: ${REMOTE_POSTGRES_HOST}:${REMOTE_POSTGRES_PORT})"
    else
        [ "${ENABLE_POSTGRES:-false}" = "true" ] && echo "    ✅ PostgreSQL" || echo "    ❌ PostgreSQL"
    fi
    if [ -n "${REMOTE_CLICKHOUSE_HOST}" ]; then
        echo "    🔗 ClickHouse (remote: ${REMOTE_CLICKHOUSE_HOST}:${REMOTE_CLICKHOUSE_PORT})"
    else
        [ "${ENABLE_CLICKHOUSE:-false}" = "true" ] && echo "    ✅ ClickHouse" || echo "    ❌ ClickHouse"
    fi
    if [ -n "${REMOTE_NEO4J_URI}" ]; then
        echo "    🔗 Neo4j (remote: ${REMOTE_NEO4J_URI})"
    else
        [ "${ENABLE_NEO4J:-false}" = "true" ] && echo "    ✅ Neo4j" || echo "    ❌ Neo4j"
    fi
    if [ -n "${REMOTE_KAFKA_BROKERS}" ]; then
        echo "    🔗 Kafka (remote: ${REMOTE_KAFKA_BROKERS})"
    else
        [ "${ENABLE_KAFKA:-false}" = "true" ] && echo "    ✅ Kafka" || echo "    ❌ Kafka"
    fi
    [ "${ENABLE_SOLR:-false}" = "true" ] && echo "    ✅ Solr" || echo "    ❌ Solr"
    if [ -n "${REMOTE_REDIS_HOST:-}" ]; then
        echo "    🔗 Redis (remote: ${REMOTE_REDIS_HOST}:${REMOTE_REDIS_PORT})"
    else
        [ "${ENABLE_REDIS:-false}" = "true" ] && echo "    ✅ Redis" || echo "    ❌ Redis"
    fi
    
    # Show enabled application services
    echo "  Application Services:"
    [ "${ENABLE_CONTEXTAPI:-false}" = "true" ] && echo "    ✅ Context API" || echo "    ❌ Context API"
    [ "${ENABLE_CXSSERVICES:-false}" = "true" ] && echo "    ✅ CXS Services" || echo "    ❌ CXS Services"
    [ "${ENABLE_INBOX:-false}" = "true" ] && echo "    ✅ Inbox" || echo "    ❌ Inbox"
    
    # Show enabled monitoring services
    echo "  Monitoring Services:"
    [ "${ENABLE_GRAFANA:-false}" = "true" ] && echo "    ✅ Grafana" || echo "    ❌ Grafana"
    [ "${ENABLE_LOKI:-false}" = "true" ] && echo "    ✅ Loki" || echo "    ❌ Loki"
    [ "${ENABLE_PROMETHEUS:-false}" = "true" ] && echo "    ✅ Prometheus" || echo "    ❌ Prometheus"
    
    # Show password info
    echo "  Passwords:"
    echo "    Admin: **** (set)"
    echo "    App: **** (set)"
echo ""

echo ""
echo "📁 Service directories:"
[ -d "data/postgres" ] && echo "  📂 data/postgres (exists)" || echo "  📂 data/postgres (not found)"
[ -d "data/clickhouse" ] && echo "  📂 data/clickhouse (exists)" || echo "  📂 data/clickhouse (not found)"
[ -d "data/neo4j" ] && echo "  📂 data/neo4j (exists)" || echo "  📂 data/neo4j (not found)"
[ -d "data/kafka" ] && echo "  📂 data/kafka (exists)" || echo "  📂 data/kafka (not found)"
[ -d "data/solr" ] && echo "  📂 data/solr (exists)" || echo "  📂 data/solr (not found)"
[ -d "data/redis" ] && echo "  📂 data/redis (exists)" || echo "  📂 data/redis (not found)"