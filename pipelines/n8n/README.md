# n8n

## Purpose
Provides a workflow automation tool that allows connecting various applications and services to create automated workflows. n8n enables users to design and execute complex sequences of operations without extensive coding.

## Configuration
- Configuration is managed via Kustomize overlays, with environment-specific settings in the `overlays/` directory (e.g., `overlays/production/`). These overlays define the n8n deployment, services, persistent storage, and any ConfigMaps.
- Secrets (e.g., database credentials if n8n is configured with an external database, API keys for connectors) are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
Deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet applies the Kustomize configurations from the `overlays/` directory.

## Backup and Restore
[Details on backup and restore procedures for n8n need to be added. This typically involves:
- Backing up the n8n database (if using an external one like PostgreSQL or MySQL).
- Backing up the n8n user data directory, which contains workflow definitions and execution logs if not using a database or if certain data is stored on the filesystem.]

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `overlays/`: Directory containing Kustomize overlays for different environments, defining the n8n deployment, persistent volumes, and services.
