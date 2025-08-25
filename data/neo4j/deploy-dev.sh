#!/bin/bash

set -euo pipefail

echo "🚀 Neo4j Development Setup"
echo "========================="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

if [ -n "${REMOTE_NEO4J_URI:-}" ]; then
  echo "⏭️  Skipping local Neo4j deploy (REMOTE_NEO4J_URI set)"
  exit 0
fi

echo "📁 Ensuring namespace exists..."
kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 Ensuring dev Secret exists (from .env) ..."
NEO4J_PASS="${NEO4J_DEV_PASSWORD:-${GLOBAL_ADMIN_PASSWORD:-devpassword}}"
kubectl -n data create secret generic neo4j-dev-secrets \
  --from-literal=NEO4J_AUTH="neo4j/${NEO4J_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "📁 Applying dev overlay..."
kubectl apply -k overlays/dev

echo "⏳ Waiting for Neo4j to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/neo4j -n data

echo "✅ Neo4j dev deployment complete"

