# SSP (Self-Service Portal)

## Purpose
[Please fill in a brief description of what the SSP application does. SSP typically stands for Self-Service Portal, which might allow users to manage their accounts, access resources, or perform other tasks independently.]

## Configuration
Configuration for the SSP is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., production) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `ssp-deployment.yaml`: Manages the deployment of the SSP pods.
- `ssp-service.yaml`: Exposes the SSP service, likely for user access.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
