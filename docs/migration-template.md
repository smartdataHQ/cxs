# Data Service Migration Template

## Key Principles

These principles are derived from our [First Principles and Directives](first-principles.md) and aligned with our [Kubernetes & GitOps standards](k8s-standards.md):

### 1. **Abstract Reusable Patterns**
**Critical:** Keep general information in root documentation, service docs minimal.
- **Root docs:** [`docs/root-deployment-system.md`](root-deployment-system.md), [`docs/migration-template.md`](migration-template.md), [`docs/first-principles.md`](first-principles.md)
- **Service docs:** Only unique connection details
- **Never duplicate:** Reference general patterns instead of repeating

### 2. **Two-File Development**
**Goal:** Minimal setup with maximum flexibility.
- **`.env`** - Cherry-pick services + set passwords only
- **`deploy-dev.sh`** - Single script to deploy everything
- **Sane defaults:** All other settings use reasonable defaults

### 3. **Avoid Complex Admin Tools**
Use simple, standard container images instead of operators for development.
- Better ARM64 compatibility, simpler maintenance
- Examples: `postgres:16-alpine`, `clickhouse/clickhouse-server`, `neo4j:5`

### 4. **Use Latest Stable Versions**
All development instances should use the latest stable version of the technology being provisioned.
- Ensures developers work with up-to-date features
- Reduces friction when upgrading to newer versions
- Maintains consistency with production environments
- See [solution-version-policy.md](solution-version-policy.md) for details

### Directory Structure

```
data/{service}/
├── base/                           # Shared configuration
│   ├── {service}.yaml             # Base resource manifests
│   ├── kustomization.yaml         # Base Kustomize config
│   └── [additional-resources/]    # Optional: backup jobs, etc.
├── overlays/                      # Environment-specific overlays
│   ├── dev/
│   │   └── kustomization.yaml     # Dev: minimal resources, simple Deployment
│   ├── staging/
│   │   └── kustomization.yaml     # Staging: operator/clustered topology when applicable
│   └── production/
│       └── kustomization.yaml     # Production: full HA topology + limits + policies
├── fleet.yaml                     # Fleet targeting by env labels
├── deploy-dev.sh                  # Developer deployment script
├── cleanup-dev.sh                 # Developer cleanup script
└── README.md                      # Concise service documentation
```

### Resource Allocation Guidelines

| Environment | Purpose | Scaling | Resource Strategy |
|-------------|---------|---------|-------------------|
| **dev** | Local development, testing | Minimal (1 replica) | No limits, smallest storage |
| **staging** | Integration testing, pre-prod | Moderate (2 replicas) | No limits, medium storage |
| **production** | Production workloads | HA (3+ nodes) | CPU/memory limits, large storage |

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

Dev scripts must:
- Apply manifests via `kubectl kustomize`/`-k overlays/dev` (no env branching)
- Be remote-aware: when `REMOTE_*` vars are set, skip local deploy and test the remote endpoint instead
- Keep tests ephemeral: `kubectl run --rm` with official client images only

Naming guidance:
- Root flags: `ENABLE_<SOLUTION>=true|false` (e.g., `ENABLE_SOLR=true`)
- Remote vars per solution: `REMOTE_<SOLUTION>_HOST`, `REMOTE_<SOLUTION>_PORT` (and add others if needed)

#### 3. **Fleet Configurations** (Self-documenting)
- `fleet.yaml` - Target environments via `env=dev|staging|production` label

#### 4. Minimal README (`README.md`)
```markdown
# {Service}

{Brief description}. See [root-deployment-system.md](../../docs/root-deployment-system.md) for setup.

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
- [ ] **Create production overlay** with HA resources (3+ nodes, large storage, limits)
- [ ] **Create Fleet config** with `env`-based targetCustomizations
- [ ] **Create deployment script** with operator installation if needed
- [ ] **Create cleanup script** for development
- [ ] **Write concise README** following template
- [ ] **Test dev deployment** on Rancher Desktop
- [ ] **Validate Kustomize builds** for all environments

### Best Practices

1. **Prefer standard images over operators** - use simple container deployments when possible
2. **Ensure ARM64 compatibility** - use multi-arch images where available
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

### Developer cherry-pick (root .env + scripts)
- Root `.env` controls which solutions to deploy locally via `ENABLE_*` flags
- Root scripts:
  - `deploy-all.sh` reads `.env` and calls each solution’s `deploy-dev.sh`
  - `test-connections.sh` delegates to per-solution `test-connection.sh`
  - `cleanup-all.sh` delegates to per-solution `cleanup-dev.sh`
- Solutions must keep their dev scripts idempotent and safe when invoked by the root scripts

Example `.env` fragment:
```bash
# === ENABLE SOLUTIONS ===
ENABLE_SOLR=true
ENABLE_POSTGRES=false

# === REMOTE ENDPOINTS (skip local deploy, test remote) ===
REMOTE_SOLR_HOST=solr.shared.dev.example.com
REMOTE_SOLR_PORT=8983
```

### Testing policy (repo-wide)
- Use ephemeral `kubectl run` tests with official client images; avoid committing extra client libraries
- Ensure tests clean up (`--rm`) and do not leave running pods

### Data layer HA (production)
- For persistence/data solutions, require HA with at least 3 nodes in production
- Use appropriate operators/clustering (avoid scaling single Deployments for stateful HA)

### Fleet examples (env selectors)

```yaml
# fleet.yaml (excerpt)
namespace: data

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

### Dev port exposure (required)
- Dev overlays must expose service ports so developers can connect easily (e.g., via port-forward).
- Ensure container ports and a ClusterIP Service are defined in the base; dev overlay inherits them.

### JVM services (Solr/Java-based) guidance
- Set explicit heap via env (e.g., `SOLR_JAVA_MEM`): start with `-Xms1g -Xmx1g` for dev on Rancher Desktop.
- Align container resources: requests `~1Gi`, limits `~2Gi` (tune per service).
- Relax dev probes (timeouts/failure thresholds) and increase `terminationGracePeriodSeconds` (~60s) to avoid false restarts on slower machines.
- Keep staging/production probes strict and pin images to stable versions.

Example (in base):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {service}
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: {service}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {service}
spec:
  template:
    spec:
      containers:
        - name: {service}
          image: {image}
          ports:
            - containerPort: 8080
```

Then developers can run:
```bash
kubectl port-forward svc/{service} 8080:8080 -n <namespace>
```
