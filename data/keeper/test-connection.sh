#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="keeper.data.svc.cluster.local"
PORT=9181

echo "🧪 Testing Keeper TCP connectivity to ${HOST}:${PORT}"

kubectl run keeper-test-$(date +%s) \
  --image=busybox:1.36.1 \
  --restart=Never \
  --namespace=data \
  --attach \
  --rm \
  --command -- sh -lc "nc -z -w 5 ${HOST} ${PORT} && echo '✅ Keeper TCP reachable' || (echo '❌ Keeper not reachable'; exit 1)"


