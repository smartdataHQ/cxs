#!/bin/bash

# Script to create or update ArgoCD OIDC secret
# Usage: ./create-oidc-secret.sh [-f|--force]
#   -f, --force: Force update even if secret already exists
#   
# Environment variables:
#   OIDC_CLIENT_SECRET: The Microsoft Entra client secret (required)

set -e

FORCE=false
NAMESPACE="argocd"
SECRET_NAME="argocd-secret"
SECRET_KEY="oidc.microsoft.clientSecret"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [-f|--force]"
            echo "  -f, --force: Force update even if secret already exists"
            echo ""
            echo "Environment variables:"
            echo "  OIDC_CLIENT_SECRET: The Microsoft Entra client secret (required)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if environment variable is set
if [ -z "$OIDC_CLIENT_SECRET" ]; then
    echo "❌ Error: OIDC_CLIENT_SECRET environment variable is not set"
    echo "Please set the environment variable with your Microsoft Entra client secret:"
    echo "  export OIDC_CLIENT_SECRET='your-client-secret-here'"
    echo "  $0"
    exit 1
fi

echo "🔐 Creating/updating ArgoCD OIDC secret in namespace: $NAMESPACE"

# Check if the secret already exists and has the OIDC key
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    # Check if the OIDC client secret key already exists
    if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$SECRET_KEY}" &>/dev/null && [ -n "$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$SECRET_KEY}" 2>/dev/null)" ]; then
        if [ "$FORCE" = false ]; then
            echo "⚠️  OIDC client secret already exists in $SECRET_NAME"
            echo "Use -f or --force to overwrite the existing secret"
            echo "Current secret value exists but is hidden for security"
            exit 0
        else
            echo "🔄 Force flag set, updating existing OIDC client secret..."
        fi
    else
        echo "📝 ArgoCD secret exists but missing OIDC key, adding OIDC client secret..."
    fi
    
    # Patch the existing secret
    kubectl patch secret "$SECRET_NAME" -n "$NAMESPACE" --type='merge' -p="{\"data\":{\"$SECRET_KEY\":\"$(echo -n "$OIDC_CLIENT_SECRET" | base64)\"}}"
    
else
    echo "➕ Creating new ArgoCD secret with OIDC client secret..."
    kubectl create secret generic "$SECRET_NAME" -n "$NAMESPACE" \
        --from-literal="$SECRET_KEY=$OIDC_CLIENT_SECRET"
fi

echo "✅ OIDC secret configured successfully!"
echo "🔄 You may need to restart ArgoCD server pods to pick up the new secret:"
echo "   kubectl rollout restart deployment argocd-server -n $NAMESPACE"