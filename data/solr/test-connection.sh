#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_SOLR_HOST:-solr.data.svc.cluster.local}"
PORT="${REMOTE_SOLR_PORT:-8983}"

echo "🧪 Testing Solr connectivity to http://${HOST}:${PORT}/solr/admin/info/system?wt=json"

kubectl run -i --rm --tty curl-solr-$(date +%s) \
  --image=curlimages/curl:8.8.0 \
  --restart=Never \
  --namespace=data \
  -- sh -lc "code=\$(curl -s -o /dev/null -w '%{http_code}' http://${HOST}:${PORT}/solr/admin/info/system?wt=json); if [ \"$code\" = \"200\" ]; then echo '✅ Solr OK'; else printf '❌ Solr check failed HTTP %s\n' \"$code\"; echo 'Hint: for dev, expose locally with:'; echo '  kubectl port-forward svc/solr 8983:8983 -n data'; echo 'Then open http://localhost:8983/solr'; exit 1; fi"
