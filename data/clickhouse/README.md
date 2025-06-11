# ClickHouse

## Purpose
Provides a high-performance, column-oriented Online Analytical Processing (OLAP) database management system. Used for analytics and processing large-scale data queries.

## Configuration
- Configuration is managed via Kustomize overlays, with environment-specific settings in the `overlays/` directory (e.g., `overlays/production/`). These overlays likely define the ClickHouse cluster setup (StatefulSet, Services, ConfigMaps).
- Secrets are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
Deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet applies the Kustomize configurations from the `overlays/` directory.

## Backup and Restore
[Details on backup and restore procedures for ClickHouse need to be added. This might involve tools like `clickhouse-backup` or custom snapshot strategies.]

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `overlays/`: Directory containing Kustomize overlays for different environments, defining the ClickHouse cluster resources.
