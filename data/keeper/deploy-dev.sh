#!/bin/bash

set -euo pipefail

echo "🚀 Keeper (ZK alternative) Development Setup"
echo "=========================================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

echo "📁 Ensuring namespace exists..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for Keeper to be ready..."
kubectl wait --for=condition=ready --timeout=180s pod -l app=keeper -n data

echo "✅ Keeper dev deployment complete"


