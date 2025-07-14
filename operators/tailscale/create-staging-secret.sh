#!/bin/bash

# Script to create Tailscale OAuth secret for staging environment
# Usage: ./create-staging-secret.sh <client_id> <client_secret>

set -e

# Check if arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <client_id> <client_secret>"
    echo ""
    echo "Example:"
    echo "  $0 k123456 ts_secret_abcdef123456"
    echo ""
    echo "Get OAuth credentials from: https://login.tailscale.com/admin/settings/keys"
    exit 1
fi

CLIENT_ID="$1"
CLIENT_SECRET="$2"

# Variables
NAMESPACE="tailscale"
SECRET_NAME="operator-oauth-staging"
CONTEXT="cxs-staging"

echo "Creating Tailscale OAuth secret for staging environment..."
echo "Context: $CONTEXT"
echo "Namespace: $NAMESPACE"
echo "Secret: $SECRET_NAME"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --context="$CONTEXT" --dry-run=client -o yaml | kubectl apply --context="$CONTEXT" -f -

# Create the secret
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-literal=client_id="$CLIENT_ID" \
    --from-literal=client_secret="$CLIENT_SECRET" \
    --context="$CONTEXT" \
    --dry-run=client -o yaml | kubectl apply --context="$CONTEXT" -f -

echo "✅ Secret created successfully!"
echo ""
echo "Next steps:"
echo "1. Verify the secret: kubectl get secret $SECRET_NAME -n $NAMESPACE --context=$CONTEXT"
echo "2. Check that your Tailscale ACL includes the dev tags: tag:dev-k8s-operator, tag:dev-k8s"
echo "3. Commit the changes in this repository to deploy via Fleet"
echo "4. Monitor the deployment: kubectl get pods -n $NAMESPACE --context=$CONTEXT"