#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_SOLR_HOST:-solr.data.svc.cluster.local}"
PORT="${REMOTE_SOLR_PORT:-8983}"
MODE="local"
[ -n "${REMOTE_SOLR_HOST:-}" ] && MODE="remote"

echo "📋 Solr Configuration"
echo "===================="
echo "  Mode: ${MODE}"
echo "  Host: ${HOST}:${PORT}"
