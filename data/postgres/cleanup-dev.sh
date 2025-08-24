#!/bin/bash

# Cleanup PostgreSQL development deployment

set -euo pipefail

echo "🗑️  Cleaning up PostgreSQL development environment..."

# Remove deployment
kubectl delete -k overlays/dev --ignore-not-found=true

# Remove secrets and configmaps
kubectl delete secret postgres-secrets -n data --ignore-not-found=true
kubectl delete configmap postgres-config -n data --ignore-not-found=true
kubectl delete configmap postgres-init -n data --ignore-not-found=true

# Remove PVC (ask for confirmation)
echo ""
read -p "🗃️  Remove persistent volume (data will be lost)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pvc postgres-dev -n data --ignore-not-found=true
    echo "✅ Persistent volume removed"
else
    echo "📁 Persistent volume preserved"
fi

echo ""
echo "✅ PostgreSQL cleanup complete!"
