#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/load-env.sh"
load_env "$ROOT_DIR/.env"

echo "📋 Schema Registry Configuration"
echo "==============================="
echo "  Endpoint: http://schema-registry.data.svc.cluster.local:8081"


