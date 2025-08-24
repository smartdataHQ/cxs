#!/bin/bash

set -euo pipefail

echo "🗑️  Cleaning up Solr dev..."

kubectl delete -k overlays/dev --ignore-not-found=true

kubectl delete pvc solr-pvc -n data --ignore-not-found=true

echo "✅ Cleanup complete"
