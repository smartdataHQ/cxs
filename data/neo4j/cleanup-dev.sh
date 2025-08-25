#!/bin/bash

set -euo pipefail

echo "🗑️  Cleaning up Neo4j dev..."

kubectl delete -k overlays/dev --ignore-not-found=true

echo "✅ Cleanup complete"

