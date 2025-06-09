# GPT Chat

## Purpose
[Please fill in a brief description of what the GPT Chat application does. It is likely a chat interface that leverages Generative Pre-trained Transformer (GPT) models, possibly interacting with the GPT API to provide conversational AI capabilities.]

## Configuration
Configuration for GPT Chat is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `gpt-chat-deployment.yaml`: Manages the deployment of the GPT Chat pods.
- `gpt-chat-service.yaml`: Exposes the GPT Chat service, likely for user interaction.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.
