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

## Secret Management

Secrets are managed separately from ArgoCD deployments using dedicated secret overlays, located at:
- **Staging**: `overlays/staging-secrets/`
- **Production**: `overlays/production-secrets/`

### Deploy Secrets
#### 1. Populate the secret-overlay .env file with proper values:
Current example:
   ```env
   # Generate JWT Key with `openssl rand -hex 48 | tr -dc 'A-Za-z0-9' | head -c 64`
   JWT_KEY=<JWT Secret key>
   HASURA_GRAPHQL_JWT_SECRET={"type":"HS256","key":"<JWT Secret key>","claims_namespace":"hasura"}
   
   # Generate with `openssl rand -hex 48 | tr -dc 'A-Za-z0-9' | head -c 32`
   HASURA_GRAPHQL_ADMIN_SECRET=f873ff9a59810597d4436990ff74058c
   # Generate with `openssl rand -hex 48 | tr -dc 'A-Za-z0-9' | head -c 32`
   CUBEJS_SECRET=ef3c1104e930cf977ae99561869a1b2f

   # Sourced from cxs-pg-pguser-cxs-pg Secret in data namespace
   SSP_DB_URL=postgresql://cxs-pg:L%2F6B%40%3F%7Db%5BQT_iM.nG5s5I%7Cht@cxs-pg-primary.data.svc:5432/ssp

   POSTGRES_HOST=cxs-pg-primary.data.svc
   POSTGRES_PORT=5432

   POSTGRES_DB=synmetrix
   POSTGRES_USER=synmetrix
   POSTGRES_PASSWORD=<password from cxs-pg-pguser-synmetrix secret in data namespace>;

   DATABASE_URL=postgresql://synmetrix:<url encoded password from synmetrix pguser>;@cxs-pg-primary.data.svc:5432/synmetrix?sslmode=prefer
               
   MINIO_ROOT_USER=<minio admin user from minio instance>
   MINIO_ROOT_PASSWORD=<minio admin password from minio instance>
   ```

#### 2. Deploy:
   ```bash
   kubectl apply -k data/synmetrix/overlays/staging-secrets/
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