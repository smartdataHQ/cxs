#!/bin/bash

set -euo pipefail

echo "🚀 Solr Development Setup"
echo "========================"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

if [ -n "${REMOTE_SOLR_HOST:-}" ]; then
  echo "⏭️  Skipping local Solr deploy (REMOTE_SOLR_HOST set)"
  exit 0
fi

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for Solr to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/solr -n data

echo "✅ Solr dev deployment complete"
