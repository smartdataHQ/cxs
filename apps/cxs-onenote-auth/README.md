# CXS OneNote Auth

## Purpose
This application likely handles authentication with Microsoft OneNote services, enabling integration or interaction with OneNote from within the Context Suite (CXS).

## Configuration
Configuration for CXS OneNote Auth is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `cxs-onenote-auth-deployment.yaml`: Manages the deployment of the CXS OneNote Auth pods.
- `cxs-onenote-auth-service.yaml`: Exposes the CXS OneNote Auth service, likely for other CXS components.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
