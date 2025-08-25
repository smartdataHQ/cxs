#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_CLICKHOUSE_HOST:-clickhouse.data.svc.cluster.local}"
HTTP_PORT="${REMOTE_CLICKHOUSE_HTTP_PORT:-8123}"
MODE="local"
[ -n "${REMOTE_CLICKHOUSE_HOST:-}" ] && MODE="remote"

echo "📋 ClickHouse Configuration"
echo "========================="
echo "  Mode: ${MODE}"
echo "  HTTP: http://${HOST}:${HTTP_PORT}"
