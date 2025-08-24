# Fleet environment labels and cluster targeting

This document defines how Rancher Fleet selects the correct Kustomize overlay per cluster using a single, standard label.

## Standard label
- Key: `env`
- Values: `dev`, `staging`, `production`

All clusters must have exactly one of these values.

## How to set the label

### Rancher UI
- Cluster Management → Clusters → Edit Config → Labels & Annotations → add `env=<dev|staging|production>` → Save

### kubectl (on the Rancher management cluster)
```bash
# Set env=staging, replace <clusterName> with the Rancher cluster name
kubectl patch clusters.management.cattle.io <clusterName> \
  --type merge \
  -p '{"metadata":{"labels":{"env":"staging"}}}'

# Verify
kubectl get clusters.management.cattle.io <clusterName> -o jsonpath='{.metadata.labels.env}'
```

## Fleet usage (per solution)
Each solution includes a `fleet.yaml` with `targetCustomizations` that select overlays by the `env` label:

```yaml
# Example excerpt
namespace: data

targetCustomizations:
  - name: dev
    clusterSelector:
      matchLabels:
        env: dev
    kustomize:
      dir: overlays/dev
  - name: staging
    clusterSelector:
      matchLabels:
        env: staging
    kustomize:
      dir: overlays/staging
  - name: production
    clusterSelector:
      matchLabels:
        env: production
    kustomize:
      dir: overlays/production
```

## Notes
- Dev can be managed either via Fleet (label the dev cluster `env=dev`) or via local scripts; staging/prod must be Fleet-managed.
- Keep existing non-standard labels (e.g., `role=production`) during migration, but new targeting should standardize on `env`.
- Per cluster prerequisites still apply (namespaces, Secrets, StorageClass, etc.).
