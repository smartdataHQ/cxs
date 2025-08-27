# Synmetrix Cluster Configuration

This directory contains cluster-level resources that support Synmetrix but are not deployed within the `synmetrix` namespace.

## Files

- `tcp-services-configmap.yaml` - ConfigMap for nginx ingress TCP services (deployed to `kube-system`)
- `nginx-ingress-tcp-config.yaml` - HelmChartConfig to enable TCP routing in RKE2 nginx ingress controller

## Deployment

These resources must be applied separately from the main Synmetrix kustomization:

```bash
# Apply TCP services ConfigMap
kubectl apply -f data/synmetrix/cluster/tcp-services-configmap.yaml

# Apply nginx ingress TCP configuration
kubectl apply -f data/synmetrix/cluster/nginx-ingress-tcp-config.yaml
```

This enables direct PostgreSQL (port 15432) and MySQL (port 13306) connections to CubeJS SQL APIs.