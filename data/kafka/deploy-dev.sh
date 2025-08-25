#!/bin/bash

set -euo pipefail

echo "🚀 Kafka Development Setup"
echo "========================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

if [ -n "${REMOTE_KAFKA_HOST:-}" ]; then
  echo "⏭️  Skipping local Kafka deploy (REMOTE_KAFKA_HOST set)"
  exit 0
fi

echo "📁 Ensuring namespace exists..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for Kafka to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kafka -n data

echo "✅ Kafka dev deployment complete"

