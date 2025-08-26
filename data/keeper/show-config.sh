#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

echo "📋 Keeper Configuration"
echo "======================"
echo "  ZK-compatible endpoint: keeper.data.svc.cluster.local:9181"


