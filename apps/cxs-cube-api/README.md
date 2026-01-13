# CXS Cube API Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the Cube Orchestrator FastAPI service.

## Structure

- `base/` - Base Kubernetes resources (Deployment, Service, ConfigMap)
- `overlays/production/` - Production-specific configurations (Ingress, image tags)
- `overlays/staging/` - Staging-specific configurations

## Prerequisites

1. **Docker Image**: The deployment expects a Docker image named `quicklookup/cxs-cube-api` available in your container registry.

2. **Kubernetes Secret**: Create a secret named `cxs-cube-api` with the following keys:
   - `CLICKHOUSE_HOST` - ClickHouse database host
   - `CLICKHOUSE_PORT` - ClickHouse database port
   - `CLICKHOUSE_USER` - ClickHouse database username
   - `CLICKHOUSE_PASSWORD` - ClickHouse database password
   - `SYNMETRIX_BASE_URL` - Synmetrix API base URL
   - `SYNMETRIX_LOGIN` - Synmetrix login username
   - `SYNMETRIX_PASSWORD` - Synmetrix password

   Example:
   ```bash
   kubectl create secret generic cxs-cube-api \
     --from-literal=CLICKHOUSE_HOST=db.contextsuite.com \
     --from-literal=CLICKHOUSE_PORT=8123 \
     --from-literal=CLICKHOUSE_USER=your_username \
     --from-literal=CLICKHOUSE_PASSWORD=your_password \
     --from-literal=SYNMETRIX_BASE_URL=https://synmetrix.contextsuite.dev \
     --from-literal=SYNMETRIX_LOGIN=your_login \
     --from-literal=SYNMETRIX_PASSWORD=your_password \
     -n solutions
   ```

## Deployment

### Production

```bash
kubectl apply -k overlays/production
```

### Staging

```bash
kubectl apply -k overlays/staging
```

## Configuration

- **Image Tag**: Managed in `overlays/*/kustomization.yaml`
- **Environment Variables**: ConfigMap values in `base/kustomization.yaml`
- **Ingress**: Production ingress configured in `overlays/production/cxs-cube-api-ingress.yaml`
  - Host: `cube.contextsuite.com`
  - TLS: Managed by cert-manager with Let's Encrypt

## Health Checks

The deployment includes:
- **Liveness Probe**: `/health` endpoint, 30s initial delay, 10s period
- **Readiness Probe**: `/health` endpoint, 10s initial delay, 5s period

## Scaling

- HorizontalPodAutoscaler configured for 1-3 replicas
- Scales based on CPU (70% target) and Memory (80% target)

## Resources

- **Requests**: 200m CPU, 512Mi memory
- **Limits**: 1000m CPU, 2Gi memory

