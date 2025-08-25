#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_REDIS_HOST:-redis.data.svc.cluster.local}"
PORT="${REMOTE_REDIS_PORT:-6379}"
MODE="local"
[ -n "${REMOTE_REDIS_HOST:-}" ] && MODE="remote"

echo "📋 Redis Configuration"
echo "====================="
echo "  Mode: ${MODE}"
echo "  Endpoint: ${HOST}:${PORT}"


