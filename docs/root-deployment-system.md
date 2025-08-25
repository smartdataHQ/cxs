# Root-Level Deployment System

## Core Vision: "Super Simple Docker-Compose" for Kubernetes

**Goal:** Create a root-level deployment system that works like docker-compose but for the entire Kubernetes-based platform, enabling frictionless developer onboarding and service orchestration.

This system is built on our [First Principles and Directives](first-principles.md), particularly:
- **Simplicity Above All** - Minimal configuration with sane defaults
- **Developer Experience First** - Single command deployments
- **Progressive Enhancement** - Start simple, add services over time
- **Backwards Compatibility** - Individual service deployments still work

### 🎯 Key Objectives

1. **Single Entry Point:** One `.env` file and one script at the root to deploy any combination of services (see `docs/env.example`)
2. **Service Cherry-Picking:** Enable/disable entire services via simple flags
3. **Minimal Configuration:** Only essential settings in root `.env`, everything else uses sane defaults
4. **Progressive Expansion:** Start simple, add more services over time as they're migrated
5. **Backwards Compatibility:** Existing individual service deployments still work
6. **Latest Stable Versions:** All dev instances use the latest stable version of the technology (see [solution-version-policy.md](solution-version-policy.md))

### 🏠 Root-Level System

1. **`.env`** - Enable/disable services + set global passwords (copy from `docs/env.example`)
2. **`deploy-all.sh`** - Deploy selected services with one command
3. **Individual service management** - Each service retains its own deployment scripts

### 🚀 Simple Workflow

```bash
cp .env.example .env     # Copy template
vim .env                 # Enable services, set passwords
./deploy-all.sh         # Deploy selected services
```

### 📋 Root .env Structure

```bash
# === ENABLE SERVICES ===
ENABLE_POSTGRES=true     # Deploy PostgreSQL
ENABLE_CLICKHOUSE=false  # Skip ClickHouse

# === GLOBAL PASSWORDS ===
GLOBAL_ADMIN_PASSWORD=devpassword
GLOBAL_APP_PASSWORD=devpassword
```

### 🛠️ Root Scripts

- `deploy-all.sh` - Deploy selected services
- `show-config.sh` - Display current configuration
- `test-connections.sh` - Test service connections
- `cleanup-all.sh` - Remove all deployments

### 📁 Individual Service Management

Each migrated service retains its own:
- `.env.example` - Service-specific configuration
- `deploy-dev.sh` - Service-specific deployment
- `show-config.sh` - Service-specific details
- `test-connection.sh` - Service-specific testing
- `cleanup-dev.sh` - Service-specific cleanup

**Security:** Development only. Use proper secrets for staging/production.

### 🌐 Environment scope and safety rails

- Root-level scripts (`deploy-all.sh`, `show-config.sh`, `test-connections.sh`, `cleanup-all.sh`) are intended for local development on Rancher Desktop only.
- Staging and production deployments are applied via Fleet with environment overlays and cluster selectors (`env=staging|production`).
- Protect production with immutable image tags, required reviews, and Fleet `targetCustomizations` that cannot match dev clusters.
