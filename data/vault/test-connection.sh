#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_VAULT_ADDR:-vault.data.svc.cluster.local}"
PORT="${REMOTE_VAULT_PORT:-8200}"

echo "🧪 Testing Vault HTTP connectivity to http://${HOST}:${PORT}/v1/sys/health"

kubectl run -i --rm --tty "curl-vault-$(date +%s)" \
  --image=curlimages/curl:8.8.0 \
  --restart=Never \
  --namespace=data \
  -- sh -lc "code=\$(curl -s -o /dev/null -w '%{http_code}' http://${HOST}:${PORT}/v1/sys/health); echo code:\$code; if [ \"\$code\" = \"200\" ] || [ \"\$code\" = \"429\" ]; then echo '✅ Vault healthy'; else printf '❌ Vault check failed HTTP %s\n' \"\$code\"; exit 1; fi"


