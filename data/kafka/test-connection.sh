#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_KAFKA_HOST:-kafka.data.svc.cluster.local}"
PORT="${REMOTE_KAFKA_PORT:-9092}"

echo "🧪 Testing Kafka connectivity to ${HOST}:${PORT}"

kubectl run -i --rm --tty kafka-test-$(date +%s) \
  --image=ghcr.io/confluentinc/cp-kafka:7.6.1 \
  --restart=Never \
  --namespace=data \
  --command -- bash -lc "
  timeout 5 bash -lc '</dev/tcp/${HOST}/${PORT}' && echo '✅ Kafka TCP reachable' || (echo '❌ Kafka not reachable'; exit 1)
  "

