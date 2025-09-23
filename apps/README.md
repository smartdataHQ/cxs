# Applications Directory

This directory contains all applications deployed to our Kubernetes clusters using Kustomize and ArgoCD. Each application follows a standardized structure with base configurations and environment-specific overlays.

## Directory Structure

Each application follows this pattern:
```
app-name/
├── README.md                    # Application-specific documentation
├── base/                        # Common Kubernetes manifests
│   ├── deployment.yaml          # Base deployment (NO image tags)
│   ├── service.yaml            # Service definition
│   ├── configmap.yaml          # Base configuration
│   └── kustomization.yaml      # Base Kustomize config
└── overlays/                    # Environment-specific customizations
    ├── staging/
    │   ├── kustomization.yaml   # Staging customizations + IMAGE TAGS
    │   └── config.yaml         # Staging-specific config
    └── production/
        ├── kustomization.yaml   # Production customizations + IMAGE TAGS
        └── config.yaml         # Production-specific config
```

## Image Management Workflow

**IMPORTANT**: Never specify image tags in base deployments. Always use overlays.

### Current Pattern (DO THIS)
```yaml
# base/deployment.yaml
spec:
  containers:
    - name: app
      image: quicklookup/myapp  # NO TAG - managed in overlays
      # Image tag managed in overlays/*/kustomization.yaml
```

```yaml
# overlays/staging/kustomization.yaml
resources:
  - ../../base

images:
  - name: quicklookup/myapp
    newTag: abc123f  # Staging image tag

# overlays/production/kustomization.yaml  
resources:
  - ../../base

images:
  - name: quicklookup/myapp
    newTag: def456g  # Production image tag
```

### Developer Workflow

#### Deploying New Image Versions

1. **For Staging Deployments:**
   ```bash
   # Edit the staging overlay
   vi apps/myapp/overlays/staging/kustomization.yaml
   
   # Update the image tag
   images:
     - name: quicklookup/myapp
       newTag: new-commit-hash
   ```

2. **For Production Deployments:**
   ```bash
   # Edit the production overlay
   vi apps/myapp/overlays/production/kustomization.yaml
   
   # Update the image tag
   images:
     - name: quicklookup/myapp
       newTag: stable-release-tag
   ```

3. **Commit and Push:**
   ```bash
   git add apps/myapp/overlays/
   git commit -m "Update myapp image to new-version"
   git push
   ```

ArgoCD will automatically detect changes and deploy the new image version to the appropriate environment.

#### Testing Image Deployments

Use `kustomize build` to verify your configuration:
```bash
# Test staging configuration
kustomize build apps/myapp/overlays/staging

# Test production configuration  
kustomize build apps/myapp/overlays/production
```

## Environment-Specific Configuration

Beyond images, overlays handle:
- **ConfigMaps**: Environment-specific settings
- **Ingress**: Different hostnames (staging vs production)
- **Resources**: Different CPU/memory limits
- **Secrets**: Environment-specific secret references
- **Replicas**: Different scaling requirements

## ArgoCD Integration

ArgoCD Applications automatically detect:
- `overlays/staging/` → Deployed to staging cluster
- `overlays/production/` → Deployed to production cluster

Each overlay becomes an ArgoCD Application that monitors its directory for changes.

## Common Patterns

### Multi-Container Deployments
```yaml
# overlays/staging/kustomization.yaml
images:
  - name: quicklookup/api
    newTag: api-v1.2.3
  - name: quicklookup/worker  
    newTag: worker-v2.1.0
```

### Environment-Specific Patches
```yaml
# overlays/production/kustomization.yaml
resources:
  - ../../base

images:
  - name: quicklookup/myapp
    newTag: v1.0.0

patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |
      - op: replace
        path: /spec/replicas
        value: 3
```

## Migration from Hardcoded Images

If you find hardcoded image tags in base deployments:

1. **Remove the tag from base:**
   ```yaml
   # Change from:
   image: quicklookup/myapp:old-tag
   # To:
   image: quicklookup/myapp
   ```

2. **Add tag to overlays:**
   ```yaml
   # Add to both staging and production kustomization.yaml:
   images:
     - name: quicklookup/myapp
       newTag: appropriate-tag-for-env
   ```

3. **Add instructional comment:**
   ```yaml
   spec:
     containers:
       - name: app
         image: quicklookup/myapp
         # Image tag managed in overlays/*/kustomization.yaml
   ```

## Best Practices

- **Never commit image tags to base deployments**
- **Always test with `kustomize build` before committing**  
- **Use meaningful commit messages for image updates**
- **Keep staging and production image tags in sync during releases**
- **Use semantic versioning or commit hashes for production images**
- **Test staging deployments before promoting to production**

For application-specific details, see the README.md file in each application directory.