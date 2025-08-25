# Kafkaui (Kafka UI)

## Purpose
Provides a web-based user interface for managing and monitoring Kafka clusters. This allows for easier inspection of topics, messages, consumer groups, and broker status.

## Configuration
- Configuration is managed using Kustomize.
- Base configuration is located in the `base/` directory (e.g., `kafkaui-deployment.yaml`, `kafkaui-service.yaml`).
- Environment-specific configurations can be managed via overlays in the `overlays/` directory (e.g., `overlays/production/`).
- Secrets (e.g., for connecting to Kafka if authentication is enabled) are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
- Kafkaui is deployed via Fleet, as specified in `fleet.yaml`.
- Fleet applies the Kustomize configurations from the `base/` and `overlays/` directories.

## Backup and Restore
Kafkaui is typically stateless. No specific backup procedures are usually required for Kafkaui itself. Ensure the Kafka cluster it connects to is properly backed up.

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `kustomization.yaml`: Root Kustomize configuration file.
- `base/`: Directory containing the base Kustomize configuration for Kafkaui.
    - `base/kafkaui-deployment.yaml`: Manages the deployment of Kafkaui pods.
    - `base/kafkaui-service.yaml`: Exposes the Kafkaui service for user access.
    - `base/kustomization.yaml`: Kustomize configuration for the base layer.
- `overlays/`: Directory for environment-specific Kustomize overlays.
