# CXS Anonymization Service

This is the Kubernetes deployment for the standalone anonymization service that provides ML-powered text anonymization capabilities.

## Overview

The anonymization service:
- Runs a single worker to ensure only one instance of the ML model is loaded
- Uses GLiNER for Named Entity Recognition (NER)
- Provides REST API endpoints for anonymization and deanonymization
- Is designed for high memory usage due to ML model requirements

## Deployment

### Prerequisites

1. Docker image: `quicklookup/cxs-anonymization:latest`
2. Kubernetes cluster with ArgoCD
3. Required secrets for authentication

### ArgoCD Application

Create an ArgoCD Application with the following configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cxs-anonymization
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/smartdataHQ/cxs
    path: apps/cxs-anonymization
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: solutions
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Manual Deployment

```bash
kubectl apply -k cxs/apps/cxs-anonymization/
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANONYMIZATION_HOST` | Service bind host | `0.0.0.0` |
| `ANONYMIZATION_PORT` | Service port | `8081` |
| `WORKERS` | Number of workers | `1` |
| `LOG_LEVEL` | Logging level | `info` |
| `PYTORCH_NUM_THREADS` | PyTorch thread count | `12` |
| `MAX_NER_TEXT_LENGTH` | Max text length for NER | `512` |
| `GLINER_MODEL_PATH` | Path to GLiNER model | `ai_models/ner_transformer` |

### Resource Requirements

- **CPU**: 8000m request, 16000m limit (up to 16 cores)
- **Memory**: 4000Mi request, 8000Mi limit
- **Storage**: 15Gi total (10Gi HF cache + 5Gi model cache)

## Health Checks

- **Liveness**: `/health` endpoint, 30s interval
- **Readiness**: `/health` endpoint, 60s initial delay

## API Endpoints

- `GET /` - Basic health check
- `GET /health` - Detailed health check with model validation
- `POST /api/anonymization/anonymize-conversation-turn` - Anonymize text
- `POST /api/anonymization/deanonymize` - Deanonymize text
- `GET /api/anonymization/prompt` - Get anonymization prompt

## Integration

The service is integrated with `cxs-services` via the environment variable:
```
ANONYMIZATION_SERVICE_URL=http://cxs-anonymization.solutions.svc.cluster.local:8081
```

## Monitoring

The service includes:
- Horizontal Pod Autoscaler (1-1 replicas)
- Health checks for both liveness and readiness
- Proper logging configuration

## Troubleshooting

### Common Issues

1. **Model Loading Failures**: Check memory allocation and HF_HOME permissions
2. **Health Check Failures**: Verify model is loaded and accessible
3. **Network Issues**: Ensure service DNS resolution works in the cluster

### Logs

```bash
kubectl logs -f deployment/cxs-anonymization -n solutions
```
