# ISL Hotel Streaming Client

## Purpose
[Please fill in a brief description of what the ISL Hotel Streaming Client application does. It is likely a client application that connects to a streaming service to process or display hotel-related data. "ISL" might refer to a specific project, vendor, or system it interacts with.]

## Configuration
Configuration for the ISL Hotel Streaming Client is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `isl-hotel-streaming-client-deployment.yaml`: Manages the deployment of the ISL Hotel Streaming Client pods.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.

Note: No Kubernetes Service is defined in the base configuration, suggesting this client might not expose any network services itself or connects outbound only.
