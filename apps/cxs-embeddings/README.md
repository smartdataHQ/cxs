# CXS Embeddings Service

This is the Kubernetes deployment for the standalone embeddings service that provides ML-powered text embedding capabilities.

## Overview

The embeddings service:
- Runs a single worker to ensure only one instance of the ML model is loaded
- Uses selected in env transformer model for text embeddings generation
- Provides REST API endpoints for text embedding generation
- Is designed for high memory usage due to ML model requirements
- Supports query prefixes for better retrieval performance

## Deployment

### Prerequisites

1. Docker image: `quicklookup/cxs-embeddings:latest`
2. Kubernetes cluster with ArgoCD
3. Required secrets for authentication

### ArgoCD Application

Create an ArgoCD Application with the following configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cxs-embeddings
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/smartdataHQ/cxs
    path: apps/cxs-embeddings
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
kubectl apply -k cxs/apps/cxs-embeddings/
```

## Configuration

### Environment Variables

#### Service Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `EMBEDDINGS_HOST` | Service bind host | `0.0.0.0` |
| `EMBEDDINGS_PORT` | Service port | `8082` |
| `WORKERS` | Number of workers | `1` |
| `LOG_LEVEL` | Logging level | `info` |
| `DEBUG` | Enable debug mode | `false` |
| `RELOAD` | Enable auto-reload | `false` |

#### Model Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `EMBEDDINGS_MODEL` | HuggingFace model name | `Qwen/Qwen3-Embedding-0.6B` |
| `EMBEDDINGS_MODEL_TYPE` | Model type | `transformers` |
| `EMBEDDINGS_QUERY_PREFIX` | Query prefix for retrieval | `Represent this query for retrieving relevant documents:` |

#### Performance Settings
| Variable | Description | Default |
|----------|-------------|---------|
| `PYTORCH_NUM_THREADS` | PyTorch thread count | `8` |
| `LOG_INPUT_TEXT` | Log input text for debugging | `false` |

#### Cache Directories
| Variable | Description | Default |
|----------|-------------|---------|
| `HF_HOME` | HuggingFace cache directory | `/tmp/hf_cache` |
| `TORCH_HOME` | PyTorch cache directory | `/tmp/torch_cache` |

### Resource Requirements

- **CPU**: 8000m request, 16000m limit (up to 16 cores)
- **Memory**: 6000Mi request, 12000Mi limit
- **Storage**: 15Gi total (10Gi HF cache + 5Gi Torch cache)

## Health Checks

- **Liveness**: `/health` endpoint, 30s interval
- **Readiness**: `/health` endpoint, 60s initial delay

## API Endpoints

- `GET /` - Basic health check
- `GET /health` - Detailed health check with model validation
- `POST /api/embeddings/generate` - Generate text embeddings
- `GET /api/embeddings/models` - List available embedding models
- `POST /api/embeddings/similarity` - Calculate text similarity

### Model Information

- **Default Model**: Qwen/Qwen3-Embedding-0.6B
- **Model Type**: Transformer-based embedding model
- **Query Enhancement**: Supports query prefixes for improved retrieval performance

## Integration

The service is integrated with `cxs-services` via the environment variable:
```
EMBEDDINGS_SERVICE_URL=http://cxs-embeddings.solutions.svc.cluster.local:8082
```

## Monitoring

The service includes:
- Horizontal Pod Autoscaler (1-1 replicas)
- Health checks for both liveness and readiness
- Proper logging configuration

## Troubleshooting

### Common Issues

1. **Model Loading Failures**: Check memory allocation and HF_HOME/TORCH_HOME permissions
2. **Health Check Failures**: Verify Qwen3-Embedding model is loaded and accessible
3. **Network Issues**: Ensure service DNS resolution works in the cluster
4. **Memory Issues**: The service requires significant memory for the transformer model
5. **Cache Issues**: Ensure cache directories have sufficient space and permissions

### Logs

```bash
kubectl logs -f deployment/cxs-embeddings -n solutions
```
