#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="schema-registry.data.svc.cluster.local"
PORT=8081

echo "🧪 Testing Schema Registry HTTP connectivity to http://${HOST}:${PORT}/subjects"

kubectl run -i --rm --tty "curl-sr-$(date +%s)" \
  --image=curlimages/curl:8.8.0 \
  --restart=Never \
  --namespace=data \
  -- sh -lc "code=\$(curl -s -o /dev/null -w '%{http_code}' http://${HOST}:${PORT}/subjects); echo code:\$code; if [ \"\$code\" = \"200\" ]; then echo '✅ Schema Registry OK'; else printf '❌ Schema Registry check failed HTTP %s\n' \"\$code\"; exit 1; fi"


