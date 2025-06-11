# Context Suite

## Purpose
[Please fill in a brief description of what the Context Suite application does. This likely serves as the frontend or client interface for the Context services.]

## Configuration
Configuration for the Context Suite is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., production, staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `contextsuite-deployment.yaml`: Manages the deployment of the Context Suite pods.
- `contextsuite-service.yaml`: Exposes the Context Suite, likely to be accessed by users.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
