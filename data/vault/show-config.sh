#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

HOST="${REMOTE_VAULT_ADDR:-vault.data.svc.cluster.local}"
PORT="${REMOTE_VAULT_PORT:-8200}"
MODE="local"
[ -n "${REMOTE_VAULT_ADDR:-}" ] && MODE="remote"

echo "📋 Vault Configuration"
echo "======================"
echo "  Mode: ${MODE}"
echo "  Address: http://${HOST}:${PORT}"


