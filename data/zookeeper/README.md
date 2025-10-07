# ZooKeeper

Apache ZooKeeper deployment for the Context Suite data infrastructure.

## Overview

ZooKeeper provides coordination services for the Kafka cluster and other distributed services in the data namespace. This deployment uses the Bitnami ZooKeeper Helm chart with GitOps management.

## Architecture

- **3-node cluster** for high availability and quorum
- **8Gi persistent storage** per node (production)
- **Bitnami ZooKeeper 3.9.2** (debian-12-r0 base image)
- **Anti-affinity rules** for pod distribution across nodes

## Configuration

### Base Configuration
- Chart: `bitnami/zookeeper:13.0.1`
- ZooKeeper version: `3.9.2`
- Client port: `2181`
- Follower port: `2888` 
- Election port: `3888`

### Environment Overlays

#### Production (`overlays/production`)
- **Resources**: 250m-375m CPU, 256Mi-384Mi RAM
- **Storage**: 8Gi per node on Longhorn
- **Logging**: ERROR level
- **Labels**: `environment=production, tier=data`

#### Staging (`overlays/staging`)  
- **Resources**: 100m-200m CPU, 128Mi-256Mi RAM
- **Storage**: 4Gi per node on Longhorn
- **Logging**: INFO level (more verbose)
- **Labels**: `environment=staging, tier=data`

## GitOps Deployment

ZooKeeper is deployed and managed via **ArgoCD**. All changes are applied through Git commits to this repository.

### ArgoCD Applications
- **Production**: `data-zookeeper` Application syncs `data/zookeeper/overlays/production`
- **Staging**: `data-zookeeper-staging` Application syncs `data/zookeeper/overlays/staging`

### Making Changes
1. **Edit configuration** in the appropriate overlay
2. **Commit changes** to the main branch  
3. **ArgoCD syncs automatically** (typically within 3 minutes)
4. **Monitor deployment** in ArgoCD UI

### Manual Sync (if needed)
```bash
# Force immediate sync via ArgoCD CLI
argocd app sync data-zookeeper

# Or use the ArgoCD web UI
# https://argo.contextsuite.com/applications/data-zookeeper
```

### Validation and Testing

```bash
# Validate manifests without applying (requires --enable-helm for Helm chart support)
kubectl kustomize data/zookeeper/overlays/production --enable-helm

# Use enhanced validation script for comprehensive checking
./scripts/validation/validate-production.sh --apps=zookeeper --verbose

# Check ArgoCD application status
argocd app get data-zookeeper

# View ArgoCD application diff (before sync)
argocd app diff data-zookeeper
```

## Migration from Helm to GitOps

This ZooKeeper configuration was migrated from a manual Helm CLI deployment to GitOps management. The migration required special handling due to Kubernetes StatefulSet immutable field constraints.

### The Challenge: Immutable Field Conflicts

StatefulSets have immutable fields (like `volumeClaimTemplates`) that cannot be changed after creation. When migrating from Helm CLI to GitOps:

- **Current StatefulSet** has Kubernetes-populated fields (`apiVersion`, `kind`, `creationTimestamp`, `status`, etc.)
- **Generated manifests** from Helm charts have clean, minimal structures
- **kubectl apply fails** with "spec: Forbidden: updates to statefulset spec" errors

### The Solution: Kustomize Strategic Patches

We solved this using Kustomize patches to make generated manifests match the existing StatefulSet structure:

```yaml
# statefulset-patch.yaml - Add Kubernetes-managed fields
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
spec:
  volumeClaimTemplates:
    - apiVersion: v1                    # ← Add these fields
      kind: PersistentVolumeClaim       # ← that Kubernetes
      metadata:
        creationTimestamp: null        # ← automatically
        name: data                      # ← populates
      spec: {...}
      status:                           # ← during StatefulSet
        phase: Pending                  # ← creation
```

### Migration Steps

1. **Kustomize + Helm Integration**: Used `helmCharts` in kustomization with `--enable-helm` flag
2. **Strategic Merge Patches**: Added patch to match existing StatefulSet structure exactly
3. **Namespace Override**: Fixed chart's server list generation using `namespaceOverride: "data"`
4. **Validation**: Verified no immutable field conflicts remain
5. **ArgoCD Integration**: Created ArgoCD Application for GitOps management
6. **Sync Success**: ArgoCD can now manage the StatefulSet without recreation

### Key Lessons Learned

- **Server-side apply `--force-conflicts`** doesn't bypass immutable field validation
- **Annotations alone** don't solve structural field differences
- **Kustomize patches** can bridge the gap between Helm-generated and Kubernetes-managed fields
- **StatefulSet recreation** would have been the only alternative (with downtime)
- **Headless services** automatically provide DNS for `zookeeper-{0,1,2}.zookeeper-headless.data.svc.cluster.local`

## Monitoring

ZooKeeper health can be monitored via:
- **Kubernetes**: Pod readiness/liveness probes
- **4lw Commands**: `srvr`, `mntr`, `ruok` enabled
- **Logs**: Available in pod logs with configurable level

## Persistence

Each ZooKeeper node uses:
- **PVC Name**: `data-zookeeper-{0,1,2}`
- **Storage Class**: `longhorn` 
- **Access Mode**: `ReadWriteOnce`
- **Retention**: PVCs are retained when pods are deleted

## Security

- **Service Account**: Dedicated `zookeeper` SA with minimal permissions
- **Security Context**: Non-root user (1001), read-only root filesystem
- **Network Policy**: Enabled with external access allowed
- **Authentication**: Disabled (internal cluster usage)

## Dependencies

- **Kafka**: Primary consumer of ZooKeeper services
- **Storage**: Longhorn for persistent volumes
- **Network**: ClusterIP services for internal communication

## Troubleshooting

### Common Issues

1. **Split-brain scenarios**: Ensure all 3 nodes are running
2. **Storage issues**: Check PVC status and Longhorn health
3. **Network connectivity**: Verify service endpoints and DNS resolution
4. **Cluster ID mismatches**: May require metadata cleanup (see Kafka documentation)
5. **Immutable field errors**: Use the validation script to identify StatefulSet conflicts
6. **GitOps sync failures**: Check if kustomization requires `--enable-helm` flag

### Health Checks
```bash
# Quick health check using 4lw commands (recommended)
kubectl exec -n data zookeeper-0 -- bash -c "echo ruok | nc localhost 2181"

# Server information and status
kubectl exec -n data zookeeper-0 -- bash -c "echo srvr | nc localhost 2181"

# Detailed monitoring metrics  
kubectl exec -n data zookeeper-0 -- bash -c "echo mntr | nc localhost 2181"

# Built-in server status check
kubectl exec -n data zookeeper-0 -- /opt/bitnami/zookeeper/bin/zkServer.sh status

# Check ZooKeeper data (interactive - requires manual exit)
kubectl exec -n data -it zookeeper-0 -- /opt/bitnami/zookeeper/bin/zkCli.sh -server localhost:2181
# Then run: ls /
# Exit with: quit

# Non-interactive ZooKeeper client (with timeout)
kubectl exec -n data zookeeper-0 -- bash -c "echo 'ls /' | timeout 10 /opt/bitnami/zookeeper/bin/zkCli.sh -server localhost:2181"
```