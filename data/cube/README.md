# Cube

## Purpose
[Please fill in a brief description of what Cube (likely Cube.js or a similar BI/analytics platform) is used for in this project. It generally serves as an open-source analytical API platform, helping to access and analyze data from various sources.]

## Configuration
- Configuration is managed via Kustomize overlays, with environment-specific settings in the `overlays/` directory (e.g., `overlays/production/`). These overlays would define the Cube deployment, services, and any necessary ConfigMaps.
- Secrets (e.g., database connection strings for Cube) are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
Deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet applies the Kustomize configurations from the `overlays/` directory.

## Backup and Restore
[Details on backup and restore procedures for Cube need to be added. This typically involves backing up the configuration and any underlying data sources Cube connects to, rather than Cube's state itself if it's stateless.]

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `overlays/`: Directory containing Kustomize overlays for different environments, defining the Cube deployment.
