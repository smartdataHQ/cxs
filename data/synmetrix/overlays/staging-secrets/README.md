# Synmetrix Secret Overlays

Secret overlays for manual deployment - **NOT** managed by ArgoCD.

## Usage

### Deploy Staging Secrets
```bash
kubectl apply -k data/synmetrix/overlays/staging-secrets/
```

### Deploy Production Secrets
1. Copy the production env file and fill in real values:
   ```bash
   cp data/synmetrix/overlays/production-secrets/synmetrix-secrets.env synmetrix-secrets-prod-real.env
   # Edit synmetrix-secrets-prod-real.env with actual values from 1Password
   ```

2. Replace the template file or update the path in kustomization.yaml

3. Deploy:
   ```bash
   kubectl apply -k data/synmetrix/overlays/production-secrets/
   ```

## Structure

- `staging-secrets/` - Staging environment secrets
- `production-secrets/` - Production environment secrets (template values)

## Security Notes

- Store actual production env files in 1Password
- Never commit production secrets to git
- Deploy secrets manually before ArgoCD deploys applications