# Translator Client

## Purpose
[Please fill in a brief description of what the Translator Client application does. It is likely a user-facing application or frontend for interacting with the Translator API, allowing users to submit text for translation and view the results.]

## Configuration
Configuration for the Translator Client is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `translator-client-deployment.yaml`: Manages the deployment of the Translator Client pods.
- `translator-client-service.yaml`: Exposes the Translator Client service, likely for user access.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
