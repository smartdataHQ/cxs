#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_KAFKA_HOST:-kafka.data.svc.cluster.local}"
PORT="${REMOTE_KAFKA_PORT:-9092}"

echo "🧪 Testing Kafka connectivity to ${HOST}:${PORT}"

kubectl run kafka-test-$(date +%s) \
  --image=busybox:1.36.1 \
  --restart=Never \
  --namespace=data \
  --attach \
  --rm \
  --command -- sh -lc "nc -z -w 5 ${HOST} ${PORT} && echo '✅ Kafka TCP reachable' || (echo '❌ Kafka not reachable'; exit 1)"

