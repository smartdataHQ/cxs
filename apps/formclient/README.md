# Form Client

## Purpose
[Please fill in a brief description of what the Form Client application does. It is likely a user-facing application or frontend for interacting with the Form API, allowing users to view, fill, and submit forms.]

## Configuration
Configuration for the Form Client is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., production) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `formclient-deployment.yaml`: Manages the deployment of the Form Client pods.
- `formclient-service.yaml`: Exposes the Form Client service, likely for user access.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
