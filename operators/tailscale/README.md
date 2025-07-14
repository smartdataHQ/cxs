# Tailscale Operator Configuration

This directory contains the Tailscale Kubernetes operator configuration for staging environment using ArgoCD GitOps.

## Directory Structure

```
authentication/tailscale/
├── README.md
├── base/
│   ├── kustomization.yaml       # Base Kustomize configuration
│   ├── namespace.yaml           # Tailscale namespace
│   └── values.yaml              # Base Helm values (common settings)
└── overlays/
    └── staging/
        ├── kustomization.yaml   # Staging Kustomize overlay
        └── staging-values.yaml  # Staging-specific settings (dev-prefixed)
```

## Environment Configuration

### Staging Environment  
- **Tags**: `tag:dev-k8s-operator`, `tag:dev-k8s` (dev-prefixed)
- **Hostname**: `dev-tailscale-operator`
- **OAuth Secret**: `operator-oauth-staging`
- **Resources**: Lower limits for development workloads
- **GitOps**: Managed by ArgoCD ApplicationSet

### Production Environment (Fleet-managed)
- **Tags**: `tag:k8s-operator`, `tag:k8s`
- **Hostname**: `tailscale-operator`
- **OAuth Secret**: `operator-oauth`
- **Resources**: Higher limits for production workloads
- **GitOps**: Still managed by Fleet (to be migrated)

## Setup Instructions

### 1. Create Tailscale OAuth Applications

You need separate OAuth applications for production and staging environments.

#### Production OAuth (if not already created)
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Create a new OAuth client with:
   - **Name**: `CXS Production Kubernetes Operator`
   - **Tags**: `tag:k8s-operator`, `tag:k8s`
   - **Access**: Read/Write for devices and routes

#### Staging OAuth (new)
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Create a new OAuth client with:
   - **Name**: `CXS Staging Kubernetes Operator`
   - **Tags**: `tag:dev-k8s-operator`, `tag:dev-k8s`
   - **Access**: Read/Write for devices and routes

### 2. Create Kubernetes Secrets

#### Production Secret (if not already created)
```bash
kubectl create secret generic operator-oauth \
  --namespace=tailscale \
  --from-literal=client_id="<PRODUCTION_CLIENT_ID>" \
  --from-literal=client_secret="<PRODUCTION_CLIENT_SECRET>" \
  --context=cxs-eu1
```

#### Staging Secret (new)
```bash
kubectl create secret generic operator-oauth-staging \
  --namespace=tailscale \
  --from-literal=client_id="<STAGING_CLIENT_ID>" \
  --from-literal=client_secret="<STAGING_CLIENT_SECRET>" \
  --context=cxs-staging
```

### 3. Update Tailscale ACL

Add the new dev tags to your Tailscale ACL policy:

```jsonc
{
  "tagOwners": {
    "tag:k8s-operator": ["your-email@domain.com"],
    "tag:k8s": ["tag:k8s-operator"],
    "tag:dev-k8s-operator": ["your-email@domain.com"],
    "tag:dev-k8s": ["tag:dev-k8s-operator"]
  },
  
  "acls": [
    // Production rules
    {
      "action": "accept",
      "src": ["tag:k8s"],
      "dst": ["*:*"]
    },
    
    // Staging rules (with dev prefix)
    {
      "action": "accept", 
      "src": ["tag:dev-k8s"],
      "dst": ["*:*"]
    }
  ]
}
```

### 4. Deploy via ArgoCD

The ArgoCD ApplicationSet will automatically discover and deploy the staging configuration:

```bash
# Check ArgoCD applications
kubectl get applications -n argocd --context=cxs-staging

# Look for the 'authentication-tailscale' application
kubectl get application authentication-tailscale -n argocd --context=cxs-staging -o yaml
```

The application will be automatically created because the ApplicationSet includes the pattern `authentication/*/overlays/staging`.

## Device Naming Convention

With this setup, Tailscale devices will be named:

### Production
- Operator: `tailscale-operator`
- Services: `ts-<service-name>-<hash>`

### Staging  
- Operator: `dev-tailscale-operator`
- Services: `ts-<service-name>-<hash>` (but with dev tags)

## Monitoring and Troubleshooting

### Check Operator Status
```bash
# Production
kubectl get pods -n tailscale --context=cxs-eu1

# Staging
kubectl get pods -n tailscale --context=cxs-staging
```

### Check Operator Logs
```bash
# Production
kubectl logs -n tailscale deployment/operator --context=cxs-eu1

# Staging
kubectl logs -n tailscale deployment/operator --context=cxs-staging
```

### Check Tailscale Resources
```bash
# List all Tailscale statefulsets (proxied services)
kubectl get statefulsets -n tailscale --context=cxs-eu1
kubectl get statefulsets -n tailscale --context=cxs-staging
```

## Security Considerations

1. **Separate OAuth Credentials**: Production and staging use different OAuth applications
2. **Tag-based Access Control**: Use ACL tags to control access between environments
3. **Resource Isolation**: Services are tagged differently to prevent cross-environment access
4. **Secret Management**: OAuth secrets are stored separately per environment

## Upgrading

To upgrade the Tailscale operator:

1. Update the version in `base/kustomization.yaml` and `overlays/staging/kustomization.yaml`
2. Commit changes to the staging branch
3. ArgoCD will automatically detect and deploy the changes

```yaml
# In both kustomization.yaml files
helmCharts:
  - name: tailscale-operator
    version: 1.84.3  # New version
```