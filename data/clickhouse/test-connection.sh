#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_CLICKHOUSE_HOST:-clickhouse.data.svc.cluster.local}"
HTTP_PORT="${REMOTE_CLICKHOUSE_HTTP_PORT:-8123}"

echo "🧪 Testing ClickHouse HTTP connectivity to http://${HOST}:${HTTP_PORT}/ping"

kubectl run ch-test-$(date +%s) \
  --image=curlimages/curl:8.8.0 \
  --restart=Never \
  --namespace=data \
  --attach \
  --rm \
  --command -- sh -lc "code=\$(curl -s -o /dev/null -w '%{http_code}' http://${HOST}:${HTTP_PORT}/ping); if [ \"$code\" = \"200\" ]; then echo '✅ ClickHouse HTTP OK'; else echo '❌ ClickHouse HTTP failed' && exit 1; fi"

