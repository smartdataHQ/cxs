# CXS Docs PVC Configuration

This document outlines the changes made to the PVC configuration for the cxs-docs application based on best practices observed in the repository and troubleshooting of persistent volume binding issues.

## Changes Made

The following changes were made to the `cxs-docs-pvc.yaml` file:

1. Added labels to the metadata section:
   - `app: cxs-docs` - Identifies the application this PVC belongs to
   - `service: cxs-docs-pvc` - Identifies the specific service/resource
   - `tier: web` - Matches the tier label used in the deployment

2. Added explicit `storageClassName: longhorn` to use the Longhorn storage class that is used by other applications in the cluster.

## Issue Resolution

The cxs-docs deployment was experiencing the following error:
```
0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

This error indicates that the PersistentVolumeClaim could not be bound to any available storage in the cluster. After examining other PVC configurations in the repository, we found that:

1. Many successful deployments use the "longhorn" storage class explicitly
2. The Neo4j deployment uses `storageClassName: longhorn` for its dynamic provisioning
3. The isl-hotel-streaming-client uses `storageClassName: longhorn-static` with an explicitly defined PersistentVolume

By specifying the "longhorn" storage class, we ensure that the PVC will use a storage class that is known to work in this cluster, rather than relying on the default storage class which might not be properly configured or might not have enough resources.

## Storage Classes in the Repository

After examining multiple PVC configurations in the repository, the following patterns were identified:

1. **Explicit Storage Classes**: Several PVCs in the repository specify a storage class, with "longhorn" and "longhorn-static" being the most common. This suggests that Longhorn is the primary storage solution used in this Kubernetes cluster.

2. **Access Modes**: Most PVCs use the `ReadWriteOnce` access mode, which allows the volume to be mounted as read-write by a single node. This is appropriate for most applications, including cxs-docs.

3. **Consistent Naming**: All PVCs follow a consistent naming pattern, typically including the application name and "-pvc" suffix (e.g., `cxs-docs-pvc`).

4. **Labeling**: Many PVCs include labels that identify the application and service they belong to, which helps with organization, filtering, and management.

5. **Storage Sizing**: Storage requests vary based on the needs of the application, ranging from 1Gi to 16Gi in the examples examined.

## Compatibility with Deployment

The cxs-docs deployment correctly references the PVC in the volumes section:

```yaml
volumes:
- name: docs-data
  persistentVolumeClaim:
    claimName: cxs-docs-pvc
```

The deployment includes a HorizontalPodAutoscaler that allows scaling between 1 and 3 replicas. Since the PVC uses the `ReadWriteOnce` access mode, each pod will get its own copy of the PVC when scaling.

## Conclusion

The updated PVC configuration addresses the "unbound immediate PersistentVolumeClaims" error by explicitly specifying the "longhorn" storage class that is used by other applications in the cluster. This change ensures that the PVC can be bound to available storage, allowing the cxs-docs pods to be scheduled successfully.