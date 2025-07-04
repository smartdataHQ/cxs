# Mimir Chat

## Purpose
[Please fill in a brief description of what the Mimir Chat application does. It could be a chat application or interface related to the Mimir system (possibly for alerts or collaboration) or a general chat service. This might be a generic version or a differently scoped instance compared to cxs-mimir-chat.]

## Configuration
Configuration for Mimir Chat is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `mimir-chat-deployment.yaml`: Manages the deployment of the Mimir Chat pods.
- `mimir-chat-service.yaml`: Exposes the Mimir Chat service.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
