#!/bin/bash

set -euo pipefail

echo "🗑️  Cleaning up ClickHouse dev..."

kubectl delete -k overlays/dev --ignore-not-found=true

echo "✅ Cleanup complete"

