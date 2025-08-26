#!/bin/bash

# Test connections to deployed CXS services

set -euo pipefail

echo "🧪 Testing CXS Service Connections"
echo "================================="

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/load-env.sh"
load_env ".env"

# Test service connections (delegate to per-solution tests)
if { [ -n "${REMOTE_POSTGRES_HOST}" ] || [ "${ENABLE_POSTGRES:-false}" = "true" ]; } \
   && [ -d "data/postgres" ] && [ -f "data/postgres/test-connection.sh" ]; then
  echo "🔌 Testing PostgreSQL connectivity..."
  (cd data/postgres && ./test-connection.sh)
  echo ""
fi

if [ "${ENABLE_CLICKHOUSE:-false}" = "true" ] && [ -d "data/clickhouse" ] && [ -f "data/clickhouse/test-connection.sh" ]; then
    echo "🔌 Testing ClickHouse connection..."
    cd data/clickhouse
    ./test-connection.sh
    cd ../..
    echo ""
fi

if [ "${ENABLE_NEO4J:-false}" = "true" ] && [ -d "data/neo4j" ] && [ -f "data/neo4j/test-connection.sh" ]; then
    echo "🔌 Testing Neo4j connection..."
    cd data/neo4j
    ./test-connection.sh
    cd ../..
    echo ""
fi

if { [ -n "${REMOTE_KAFKA_HOST:-}" ] || [ -n "${REMOTE_KAFKA_BROKERS:-}" ] || [ "${ENABLE_KAFKA:-false}" = "true" ]; } \
   && [ -d "data/kafka" ] && [ -f "data/kafka/test-connection.sh" ]; then
    echo "🔌 Testing Kafka connection..."
    cd data/kafka
    ./test-connection.sh
    cd ../..
    echo ""
fi

if [ "${ENABLE_SCHEMA_REGISTRY:-false}" = "true" ] && [ -d "data/kafka-schema-registry" ] && [ -f "data/kafka-schema-registry/test-connection.sh" ]; then
    echo "🔌 Testing Schema Registry connection..."
    cd data/kafka-schema-registry
    ./test-connection.sh
    cd ../..
    echo ""
fi

if { [ -n "${REMOTE_SOLR_HOST:-}" ] || [ "${ENABLE_SOLR:-false}" = "true" ]; } \
   && [ -d "data/solr" ] && [ -f "data/solr/test-connection.sh" ]; then
    echo "🔌 Testing Solr connection..."
    cd data/solr
    ./test-connection.sh
    cd ../..
    echo ""
fi

if { [ -n "${REMOTE_REDIS_HOST:-}" ] || [ "${ENABLE_REDIS:-false}" = "true" ]; } \
   && [ -d "data/redis" ] && [ -f "data/redis/test-connection.sh" ]; then
    echo "🔌 Testing Redis connection..."
    cd data/redis
    ./test-connection.sh
    cd ../..
    echo ""
fi

if { [ -n "${REMOTE_VAULT_ADDR:-}" ] || [ "${ENABLE_VAULT:-false}" = "true" ]; } \
   && [ -d "data/vault" ] && [ -f "data/vault/test-connection.sh" ]; then
    echo "🔌 Testing Vault connection..."
    cd data/vault
    ./test-connection.sh
    cd ../..
    echo ""
fi

echo "✅ Connection testing complete!"