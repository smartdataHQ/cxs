#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="neo4j.data.svc.cluster.local"
PORT="7687"

echo "🧪 Testing Neo4j BOLT connectivity to ${HOST}:${PORT}"

kubectl run neo4j-test-$(date +%s) \
  --image=busybox:1.36.1 \
  --restart=Never \
  --namespace=data \
  --attach \
  --rm \
  --command -- sh -lc "nc -z -w 5 ${HOST} ${PORT} && echo '✅ Neo4j TCP reachable' || (echo '❌ Neo4j not reachable'; exit 1)"

