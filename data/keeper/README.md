# Keeper

## Purpose
[Please fill in a brief description of what Keeper is used for in this project. The name is generic; it could be a password manager, a secrets management tool (though Vault is also present), a coordination service like Zookeeper (though Kafka usually bundles its own or uses a central one), or another type of stateful application requiring persistent storage.]

## Configuration
- Configuration is managed via Kustomize overlays, with environment-specific settings in the `overlays/` directory (e.g., `overlays/production/`). These overlays would define the Keeper deployment, services, and any necessary ConfigMaps or PersistentVolumeClaims.
- Secrets are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
Deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet applies the Kustomize configurations from the `overlays/` directory.

## Backup and Restore
[Details on backup and restore procedures for Keeper need to be added. The specific method will depend heavily on what kind of application Keeper is.]

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `overlays/`: Directory containing Kustomize overlays for different environments, defining the Keeper deployment.
