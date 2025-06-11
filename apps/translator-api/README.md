# Translator API

## Purpose
[Please fill in a brief description of what the Translator API application does. It likely provides machine translation services, allowing other applications to translate text between different languages.]

## Configuration
Configuration for the Translator API is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `translator-api-deployment.yaml`: Manages the deployment of the Translator API pods.
- `translator-api-service.yaml`: Exposes the Translator API internally within the cluster.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
