# GPT API

## Purpose
[Please fill in a brief description of what the GPT API application does. It likely provides an interface to Generative Pre-trained Transformer (GPT) models, offering Large Language Model (LLM) functionalities to other applications.]

## Configuration
Configuration for the GPT API is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `gpt-api-deployment.yaml`: Manages the deployment of the GPT API pods.
- `gpt-api-service.yaml`: Exposes the GPT API internally within the cluster.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
