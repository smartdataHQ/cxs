#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_REDIS_HOST:-redis.data.svc.cluster.local}"
PORT="${REMOTE_REDIS_PORT:-6379}"

echo "🧪 Testing Redis TCP connectivity to ${HOST}:${PORT}"

kubectl run redis-test-$(date +%s) \
  --image=busybox:1.36.1 \
  --restart=Never \
  --namespace=data \
  --attach \
  --rm \
  --command -- sh -lc "nc -z -w 5 ${HOST} ${PORT} && echo '✅ Redis TCP reachable' || (echo '❌ Redis not reachable'; exit 1)"


