# Inbox

## Purpose
[Please fill in a brief description of what the Inbox application does. It might serve as a generic system for receiving and processing messages, notifications, tasks, or other types of incoming data.]

## Configuration
Configuration for the Inbox application appears to be managed per environment using Kustomize, for example, in the `overlays/production/` directory. It does not follow the typical `base/` and `overlays/` structure found in some other applications.
- Specific configurations for environments like production are located in their respective `overlays/` subdirectories (e.g., `overlays/production/`).

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
Kubernetes resource definitions for the Inbox application are managed within its environment-specific overlay directories. For example, for the production environment, these can be found in `overlays/production/`:
- `inbox-deployment.yaml`: Manages the deployment of the Inbox pods.
- `inbox-service.yaml`: Exposes the Inbox service.
- `inbox-ingress.yaml`: Configures ingress rules for accessing the Inbox.
- `inbox-config.yaml`: Contains specific configuration for the Inbox application.
- `inbox-autoscaler.yaml`: Defines autoscaling rules for the Inbox deployment.
- `kustomization.yaml`: Defines the Kustomize configuration for the production overlay.
