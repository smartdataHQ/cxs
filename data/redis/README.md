# redis

This install redis using helm chart from bitnami.

## Authentication

Redis is configured to use an external secret for authentication to prevent password regeneration during syncs.

### Secret Management

The `redis-auth` secret must be created in the following namespaces:
- `data` (for Redis itself)
- `solutions` (for applications like gpt-api)
- `api` (for other services)

### Initialize Redis Authentication

```bash
# Auto-generate secure password
make k8s.redis.init

# Or provide specific password
REDIS_PASSWORD=mysecurepassword make k8s.redis.init
```

This command will:
1. Generate a secure random password (if not provided)
2. Create `redis-auth` secret in all required namespaces
3. Configure Redis to use the external secret

### Preserving Existing Password

To preserve an existing Redis password when reinitializing:

```bash
# Extract current password from existing secret
REDIS_PASSWORD=$(kubectl get secret redis-auth -n data -o jsonpath='{.data.password}' | base64 -d)

# Reinitialize with preserved password
REDIS_PASSWORD=$REDIS_PASSWORD make k8s.redis.init
```

This ensures continuity when updating secrets across namespaces without changing the actual Redis password.

### Configuration

Redis expects:
- Secret name: `redis-auth`
- Secret key: `password`
- Configured in `base/kustomization.yaml` via `existingSecret`

This prevents Redis from generating new passwords during deployments and ensures consistent authentication across all dependent applications.