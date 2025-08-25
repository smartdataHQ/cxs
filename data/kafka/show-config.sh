#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_KAFKA_HOST:-kafka.data.svc.cluster.local}"
PORT="${REMOTE_KAFKA_PORT:-9092}"
MODE="local"
[ -n "${REMOTE_KAFKA_HOST:-}" ] && MODE="remote"

echo "📋 Kafka Configuration"
echo "====================="
echo "  Mode: ${MODE}"
echo "  Broker: ${HOST}:${PORT}"
