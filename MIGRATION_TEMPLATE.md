# Data Service Migration Template

## Key Principles

These principles are derived from our [First Principles and Directives](FIRST_PRINCIPLES.md):

### 1. **Abstract Reusable Patterns**
**Critical:** Keep general information in root documentation, service docs minimal.
- **Root docs:** [`docs/root-deployment-system.md`](docs/root-deployment-system.md), [`docs/migration-template.md`](docs/migration-template.md), [`docs/first-principles.md`](docs/first-principles.md)
- **Service docs:** Only unique connection details
- **Never duplicate:** Reference general patterns instead of repeating

### 2. **Two-File Development**
**Goal:** Minimal setup with maximum flexibility.
- **`.env`** - Cherry-pick services + set passwords only
- **`deploy-dev.sh`** - Single script to deploy everything
- **Sane defaults:** All other settings use reasonable defaults

This follows our **Simplicity Above All** and **Developer Experience First** principles.

### 3. **Avoid Complex Admin Tools**
Use simple, standard container images instead of operators for development.
- Better ARM64 compatibility, simpler maintenance
- Examples: `postgres:16-alpine`, `clickhouse/clickhouse-server`, `neo4j:5`

This follows our **Simplicity Above All** principle and addresses real-world compatibility issues (see historical migration from Percona to standard PostgreSQL).

### 4. **Use Latest Stable Versions**
All development instances should use the latest stable version of the technology being provisioned.
- Ensures developers work with up-to-date features
- Reduces friction when upgrading to newer versions
- Maintains consistency with production environments
- See `docs/solution-version-policy.md` for details

This follows our **Developer Experience First** principle.

### Directory Structure

```
data/{service}/
├── base/                           # Shared configuration
│   ├── {service}.yaml             # Base resource manifests
│   ├── kustomization.yaml         # Base Kustomize config
│   └── [additional-resources/]    # Optional: backup jobs, etc.
├── overlays/                      # Environment-specific overlays
│   ├── dev/
│   │   └── kustomization.yaml     # Dev: minimal resources
│   ├── staging/
│   │   └── kustomization.yaml     # Staging: moderate resources
│   └── production/
│       └── kustomization.yaml     # Production: full resources + limits
├── fleet.yaml                     # Default Fleet config (dev)
├── fleet-dev.yaml                 # Dev-specific Fleet targeting
├── fleet-staging.yaml             # Staging-specific Fleet targeting
├── fleet-production.yaml          # Production-specific Fleet targeting
├── deploy-dev.sh                  # Developer deployment script
├── cleanup-dev.sh                 # Developer cleanup script
└── README.md                      # Concise service documentation
```

### Resource Allocation Guidelines

| Environment | Purpose | Scaling | Resource Strategy |
|-------------|---------|---------|-------------------|
| **dev** | Local development, testing | Minimal (1 replica) | No limits, smallest storage |
| **staging** | Integration testing, pre-prod | Moderate (2 replicas) | No limits, medium storage |
| **production** | Production workloads | HA (3+ replicas) | CPU/memory limits, large storage |

### Standard Files to Create

#### 1. **`.env.example`** - Minimal Configuration
```bash
# === ENABLE SERVICES ===
ENABLE_{SERVICE}=true
ENABLE_{OPTIONAL}=false

# === PASSWORDS ===
ADMIN_PASSWORD=devpassword
APP_PASSWORD=devpassword
```

#### 2. **Deployment Scripts**
- `deploy-dev.sh` - Deploy everything with current config
- `show-config.sh` - Display current configuration
- `test-connection.sh` - Test service connectivity
- `cleanup-dev.sh` - Remove development deployment

#### 3. **Fleet Configurations** (Self-documenting)
- `fleet.yaml` - Default deployment (dev environment)
- `fleet-dev.yaml` - Development cluster targeting
- `fleet-staging.yaml` - Staging cluster targeting
- `fleet-production.yaml` - Production cluster targeting

#### 3. Minimal README (`README.md`)
```markdown
# {Service}

{Brief description}. See [ROOT_DEPLOYMENT_SYSTEM.md](../../ROOT_DEPLOYMENT_SYSTEM.md) for setup.

## Two-File Setup

```bash
cp .env.example .env     # Copy and customize
vim .env                 # Enable services, set passwords
./deploy-dev.sh         # Deploy everything
```

## .env File

Contains only what you need to customize:

```bash
ENABLE_{SERVICE}=true
ENABLE_{OPTIONAL}=false

ADMIN_PASSWORD=devpassword
APP_PASSWORD=devpassword
```

## Connection

**Host:** `{service-host}`  
**Default:** `{username}:{password}` (customizable in `.env`)  
**Additional:** {service-specific details}

```bash
./test-connection.sh    # Test connection
./show-config.sh        # View configuration
./cleanup-dev.sh        # Remove deployment
```
```

### Migration Checklist

For each data service:

- [ ] **Create base directory** and move existing config
- [ ] **Update base config** with environment-neutral defaults
- [ ] **Create dev overlay** with minimal resources (1 replica, small storage)
- [ ] **Create staging overlay** with moderate resources (2 replicas, medium storage)
- [ ] **Create production overlay** with HA resources (3+ replicas, large storage, limits)
- [ ] **Create Fleet configs** for each environment + default
- [ ] **Create deployment script** with operator installation if needed
- [ ] **Create cleanup script** for development
- [ ] **Write concise README** following template
- [ ] **Test dev deployment** on Rancher Desktop
- [ ] **Validate Kustomize builds** for all environments



### Best Practices

1. **Prefer standard images over operators** - use simple container deployments when possible
2. **Tryp to Ensure ARM64 compatibility** - use multi-arch images where available
3. **Include access information** - every service must have connection details and test commands
4. **Keep base config environment-neutral** - no hardcoded replicas or storage sizes
5. **Use appropriate resource scaling** - dev should run on minimal resources
6. **Maintain backwards compatibility** - default fleet.yaml deploys dev environment
7. **Enable selective deployment** - developers choose what they need
8. **Document concisely** - focus on essential information only
9. **Test thoroughly** - validate all Kustomize builds before deployment
10. **Use latest stable versions** - all dev instances should use the latest stable version of the technology

### Deployment strategy (Kustomize-first)
- Keep base manifests environment-neutral (`base/`)
- Put all environment differences in `overlays/dev|staging|production`
- Apply overlays via Fleet using `targetCustomizations` (cluster label selectors)
- Dev scripts are optional helpers for Secrets/testing; they must apply manifests via `kubectl kustomize`/`-k` and avoid environment branching

### Testing policy (repo-wide)
- Use ephemeral `kubectl run` tests with official client images; avoid committing extra client libraries
- Ensure tests clean up (`--rm`) and do not leave running pods

### Data layer HA (production)
- For persistence/data solutions, require HA with at least 3 nodes in production
- Use appropriate operators/clustering (avoid scaling single Deployments for stateful HA)

### Fleet examples (env selectors)

```yaml
# fleet.yaml (excerpt)
targetCustomizations:
  - name: production
    clusterSelector:
      matchLabels:
        env: production
    kustomize:
      dir: overlays/production
  - name: staging
    clusterSelector:
      matchLabels:
        env: staging
    kustomize:
      dir: overlays/staging
  - name: dev
    clusterSelector:
      matchLabels:
        env: dev
    kustomize:
      dir: overlays/dev
```

### Dev overlay (Rancher Desktop) example

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
images:
  - name: quicklookup/{service}
    newTag: dev-latest
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/replicas
        value: 1
      - op: add
        path: /spec/template/spec/containers/0/imagePullPolicy
        value: Never
configMapGenerator:
  - name: {service}-config
    behavior: merge
    literals:
      - LOG_LEVEL=debug
```