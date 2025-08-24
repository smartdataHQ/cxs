# Migration Principles

These principles are derived from our [First Principles and Directives](FIRST_PRINCIPLES.md):

## Key Principles

### 1. **Abstract Reusable Patterns**
**Critical:** Keep general information in root documentation, service docs minimal.
- **Root docs:** [`docs/root-deployment-system.md`](docs/root-deployment-system.md), [`docs/migration-template.md`](docs/migration-template.md), [`docs/first-principles.md`](docs/first-principles.md)
- **Service docs:** Only unique connection details
- **Never duplicate:** Reference general patterns instead of repeating

This follows our **Simplicity Above All** principle by reducing redundancy and maintenance overhead.

### 2. **Two-File Development**
**Goal:** Minimal setup with maximum flexibility.
- **`.env`** - Cherry-pick services + set passwords only
- **`deploy-dev.sh`** - Single script to deploy everything
- **Sane defaults:** All other settings use reasonable defaults

This follows our **Developer Experience First** and **Simplicity Above All** principles.

### 3. **Avoid Complex Admin Tools**
Use simple, standard container images instead of operators for development.
- Better ARM64 compatibility, simpler maintenance
- Examples: `postgres:16-alpine`, `clickhouse/clickhouse-server`, `neo4j:5`

This follows our **Simplicity Above All** principle and addresses real-world compatibility issues (see historical migration from Percona to standard PostgreSQL).

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
└── README.md                      # Concise service documentation
```

## Refactor approach (2025): one solution at a time

We will migrate solutions incrementally to the dev/staging/production pattern. The first target is `data/postgres` for Rancher Desktop dev, followed by staging and production overlays. Staging and production remain stable until their overlays are explicitly introduced.

### Steps per solution
1. Make base manifests environment-agnostic (no replicas, limits, or env-specific hosts)
2. Add `overlays/dev` (replicas: 1, `imagePullPolicy: Never`, dev tags), `overlays/staging`, and `overlays/production`
3. Extend `fleet.yaml` with `targetCustomizations` selecting `env=dev|staging|production`
4. Provide `.env.example`, `deploy-dev.sh`, `test-connection.sh`, `cleanup-dev.sh`
5. Validate with `kustomize build` for each overlay; apply dev to Rancher Desktop
6. Verify staging on a staging cluster; document access and rollback

### Acceptance criteria
- Dev overlay deploys successfully on Rancher Desktop and passes connectivity tests
- Staging overlay mirrors prod topology with pinned image tags and TLS
- Production overlay enforces requests/limits, probes, PodSecurity, NetworkPolicies, and backups
- Documentation updated per template with connection details and scripts