# Synmetrix Application

This Kustomize configuration deploys the Synmetrix application stack to Kubernetes, leveraging existing Redis and Postgres infrastructure with a simplified, secure approach.

## Architecture

The application consists of:
- **Actions**: Custom business logic service
- **CubeJS**: Analytics API and dashboard
- **CubeStore**: CubeJS storage engine
- **Hasura**: GraphQL API gateway
- **MinIO**: Object storage
- **Client**: Frontend application
- **MailHog**: Email testing service

## Prerequisites

- Existing Redis deployment: `redis-master.data.svc.cluster.local`
- Existing Postgres deployment: `cxs-pg-primary.data.svc`
- Docker images available:
  - `quicklookup/synmetrix-client:latest`
  - `quicklookup/synmetrix-actions:latest`
  - `quicklookup/synmetrix-cube:latest`

## Simplified Patch Structure

Only **4 patches** are used (reduced from 12):

1. **`cubejs-resources.yaml`** - CPU/memory limits for CubeJS
2. **`hasura-resources.yaml`** - CPU/memory limits for Hasura
3. **`enable-ingress.yaml`** - Complete ingress configuration
4. **`external-database-config.yaml`** - All external database and environment configs

## Secret Management

Secrets are managed separately from ArgoCD deployments using dedicated secret overlays.

### Secret Overlays

- **Staging**: `overlays/staging-secrets/`
- **Production**: `overlays/production-secrets/`

### Deploy Secrets

**Staging**:
```bash
kubectl apply -k data/synmetrix/overlays/staging-secrets/
```

**Production**:
1. Copy production template and add real values from 1Password:
   ```bash
   cp overlays/production-secrets/synmetrix-secrets.env production-real.env
   # Edit production-real.env with actual values
   ```
2. Update `overlays/production-secrets/kustomization.yaml` to reference the real env file
3. Deploy:
   ```bash
   kubectl apply -k data/synmetrix/overlays/production-secrets/
   ```

### Important Notes

- **Deploy secrets BEFORE ArgoCD deploys the application**
- Store production env files in 1Password, never commit to git
- Secrets use `disableNameSuffixHash: true` for consistent naming
- ArgoCD applications expect `synmetrix-secrets` to exist

### Deployment Steps

1. **Update secrets**: Replace placeholder values in the secret
2. **Update ingress**: Change hostname in `patches/enable-ingress.yaml`
3. **Deploy via Fleet**: The app will automatically deploy to production clusters

## Services Exposed

- **Client**: Main web interface (via ingress `/`)
- **Hasura**: GraphQL API (via ingress `/v1/graphql`)
- **CubeJS**: Analytics API (via ingress `/api`)
- **CubeJS SQL APIs**: PostgreSQL-compatible (port 15432) and MySQL-compatible (port 13306) APIs

### Enabling CubeJS SQL API Access

To enable external access to CubeJS SQL APIs, apply the cluster-level configuration:

```bash
kubectl apply -f data/synmetrix/cluster/
```

See `cluster/README.md` for details on direct database connections via `psql` and `mysql` clients.

## External Dependencies

- **PostgreSQL**: Uses existing `cxs-pg-primary.data.svc:5432`
- **Redis**: Uses existing `redis-master.data.svc.cluster.local:6379`
- **Ingress**: Requires nginx ingress controller with cert-manager

## Configuration

- **Hostname**: `synmetrix.contextsuite.dev` (update in ingress patch)
- **SSL**: Automatic via cert-manager with `letsencrypt-prod`
- **Resources**: Production-level CPU/memory limits applied 