#!/bin/bash

set -euo pipefail

echo "🚀 Schema Registry Development Setup"
echo "==================================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

echo "📁 Ensuring namespace exists..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for Schema Registry to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/schema-registry -n data

echo "✅ Schema Registry dev deployment complete"


