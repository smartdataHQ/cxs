# Playground

## Purpose
[Please fill in a brief description of what the Playground application is used for. It typically serves as an experimental environment for testing new features, services, or configurations before deploying them to staging or production. It might also be a space for developers to try out new technologies.]

## Configuration
Configuration for the Playground is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., production - though 'production' for a playground might mean a stable version of the playground itself) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `playground-deployment.yaml`: Manages the deployment of the Playground pods.
- `playground-service.yaml`: Exposes the Playground service.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
