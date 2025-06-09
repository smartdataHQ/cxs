# CXS Services

## Purpose
[Please fill in a brief description of what CXS Services provides. This appears to be a general backend application or a collection of microservices for the Context Suite (CXS).]

## Configuration
Configuration for CXS Services is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `cxs-services-deployment.yaml`: Manages the deployment of the CXS Services pods.
- `cxs-services-service.yaml`: Exposes the CXS Services internally within the cluster.
- `cxs-services-volumes.yaml`: Defines volume configurations for CXS Services, if any.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
