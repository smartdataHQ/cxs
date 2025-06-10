# Ingress

## Purpose
[Please fill in a brief description of what this Ingress configuration does. It likely defines global or default Ingress controller settings, Ingress resources for specific shared services, or a customized Ingress setup for the cluster.]

## Configuration
Configuration for Ingress resources appears to be managed per environment using Kustomize, for example, in the `overlays/production/` directory. It does not follow the typical `base/` and `overlays/` structure found in some other applications.
- Specific configurations for environments like production are located in their respective `overlays/` subdirectories (e.g., `overlays/production/`).

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This Ingress configuration is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration can be found in `fleet.yaml`.

## Kubernetes Resources
Kubernetes resource definitions for this Ingress setup are managed within its environment-specific overlay directories. For example, for the production environment, these can be found in `overlays/production/`:
- `ingress-deployment.yaml`: Manages the deployment of Ingress controller pods (if this defines a custom controller).
- `ingress-service.yaml`: Exposes the Ingress controller service.
- `ingress-ingress.yaml`: Defines Ingress rules.
- `ingress-config.yaml`: Contains specific configuration for the Ingress setup.
- `ingress-autoscaler.yaml`: Defines autoscaling rules for the Ingress deployment.
- `kustomization.yaml`: Defines the Kustomize configuration for the production overlay.
