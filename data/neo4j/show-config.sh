#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="neo4j.data.svc.cluster.local"
PORT="7687"
MODE="local"
[ -n "${REMOTE_NEO4J_URI:-}" ] && MODE="remote" && HOST="${REMOTE_NEO4J_URI}"

echo "📋 Neo4j Configuration"
echo "====================="
echo "  Mode: ${MODE}"
echo "  Bolt: ${HOST}:${PORT}"
