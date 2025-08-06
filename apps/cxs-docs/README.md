# CXS Documentation

## Purpose
This application serves the Context Suite documentation, providing a centralized location for users to access documentation for all Context Suite products and services. It is deployed using the Docker image `quicklookup/cxs-utils:91df8784d7cfc2079c3048267a3db20c9cfecc0c` and is accessible at docs.contextsuite.com.

## Configuration
Configuration for CXS Documentation is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (production) are managed via overlays in the `overlays/` directory.

### ConfigMap
Non-sensitive configuration is stored in the `cxs-docs-config.yaml` ConfigMap in the production overlay. This includes:
- Airtable configuration (base ID, table IDs)
- Directory paths
- Backup settings
- Runtime settings

### Secrets
**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

The following secrets need to be created in Rancher under the name `cxs-docs`:

| Key | Description |
|-----|-------------|
| `OPENAI_API_KEY` | API key for OpenAI services |
| `GEMINI_API_KEY` | API key for Google Gemini services |
| `AIRTABLE_API_KEY` | API key for Airtable access |

To create these secrets in Rancher:
1. Navigate to the Rancher dashboard
2. Go to the "solutions" namespace
3. Select "Secrets" from the menu
4. Click "Create" and select "Secret"
5. Enter "cxs-docs" as the name
6. Add each key-value pair from the table above
7. Click "Create"

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `cxs-docs-deployment.yaml`: Manages the deployment of the documentation pods, including the HorizontalPodAutoscaler for automatic scaling.
- `cxs-docs-service.yaml`: Exposes the documentation service internally within the cluster.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.

The production overlay adds the following resources:
- `cxs-docs-ingress.yaml`: Configures the Ingress resource to expose the documentation service externally at docs.contextsuite.com.
- `kustomization.yaml`: Defines the Kustomize configuration for the production overlay.