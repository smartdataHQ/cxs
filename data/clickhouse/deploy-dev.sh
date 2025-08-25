#!/bin/bash

set -euo pipefail

echo "🚀 ClickHouse Development Setup"
echo "=============================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

if [ -n "${REMOTE_CLICKHOUSE_HOST:-}" ]; then
  echo "⏭️  Skipping local ClickHouse deploy (REMOTE_CLICKHOUSE_HOST set)"
  exit 0
fi

echo "📁 Ensuring namespace exists..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for ClickHouse to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/clickhouse -n data

echo "✅ ClickHouse dev deployment complete"

