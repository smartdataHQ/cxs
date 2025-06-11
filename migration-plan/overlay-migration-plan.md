# Overlay Migration Plan

This plan outlines the process for restructuring workloads to follow consistent Kustomize patterns for Argo CD migration.

## Current Migration Status

**Overall Progress**: 95% complete for existing apps structure, 4 new Helm workloads identified for migration

**Apps with Base/Overlay Structure**: 21/21 completed  
**Apps with Staging Overlays**: 13/21 completed  
**Argo CD Applications Deployed**: 19 applications

## Restructuring Pattern

For workloads without a proper `base` directory (only `production`):

1. Create a new `base` directory
2. Move all production manifest files to `base`
3. Create a minimal `production` overlay that references the `base`
4. Create a `staging` overlay that also references the `base`
5. Update any environment-specific configurations
6. **Use configMapGenerator** instead of static ConfigMaps for automatic hash suffixes
7. **Consolidate common resources** (ConfigMaps, Ingress) to base and patch in overlays

## Implementation Status (Apps Directory)

### ✅ COMPLETED: Apps with Base + Production + Staging + Modern Patterns
- [x] **contextapi** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **contextsuite** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **ctxllm** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **cxs-mimir-api** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **cxs-mimir-chat** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **cxs-onenote-auth** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ⚠️ (OutOfSync)
- [x] **cxs-services** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **formapi** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **formclient** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **gpt-api** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ⚠️ (Degraded)
- [x] **gpt-chat** - Base ✅ | Production ✅ | Staging ✅ | ConfigMapGenerator ✅ | Modern Patterns ✅
- [x] **ingress** - Base ✅ | Production ✅ | Staging ✅ | Argo CD ✅
- [x] **playground** - Base ✅ | Production ✅ | Staging ✅ | ConfigMapGenerator ✅ | Modern Patterns ✅

### ⚠️ PARTIAL: Apps with Base + Production (Missing Staging)
- [x] **isl-hotel-streaming-client** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **mimir-api** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **mimir-chat** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **service-runner** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **ssp** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **translator-api** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌
- [x] **translator-client** - Base ✅ | Production ✅ | Staging ❌ | Argo CD ❌

### ❌ INCOMPLETE: Apps Missing Base Structure
- [ ] **inbox** - Base ❌ | Production ✅ | Staging ❌ | Argo CD ❌
  - [ ] Create base from production manifests
  - [ ] Create minimal production overlay
  - [ ] Create staging overlay
  - [ ] Deploy via Argo CD

## 🚨 NEW: Helm Workloads Requiring Migration

These workloads are currently managed by Helm and need to be migrated to Argo CD GitOps:

### Data Services
- [ ] **redis** (data namespace)
  - [ ] Create `data/redis/base/` structure
  - [ ] Document current Helm values: `helm get values redis -n data`
  - [ ] Convert to Kustomize base resources
  - [ ] Create production overlay with current configuration
  - [ ] Create staging overlay with reduced resources
  - [ ] Deploy via Argo CD application
  - [ ] Remove Helm installation after verification

### Monitoring Services
- [ ] **kube-state-metrics** (monitoring namespace)
  - [ ] Create `monitoring/kube-state-metrics/base/` structure
  - [ ] Document current Helm values: `helm get values kube-state-metrics -n monitoring`
  - [ ] Create production and staging overlays
  - [ ] Deploy via Argo CD application
  - [ ] Remove Helm installation

- [ ] **postgres-exporter** (monitoring namespace)
  - [ ] Create `monitoring/postgres-exporter/base/` structure
  - [ ] Document current Helm values: `helm get values postgres-exporter -n monitoring`
  - [ ] Create production and staging overlays
  - [ ] Deploy via Argo CD application
  - [ ] Remove Helm installation

- [ ] **victoria-metrics-agent** (monitoring namespace)
  - [ ] Create `monitoring/victoria-metrics-agent/base/` structure
  - [ ] Document current Helm values: `helm get values vma -n monitoring`
  - [ ] Create production and staging overlays
  - [ ] Deploy via Argo CD application
  - [ ] Remove Helm installation

## Next Steps Priority Order

### 🔥 Priority 1: Complete Missing Apps Structure
1. **inbox** - Create base/overlay structure and deploy to Argo CD
2. Create staging overlays for 9 apps that are missing them

### 🔥 Priority 2: Migrate Helm Workloads
1. **redis** - Critical data service, migrate with caution
2. **monitoring services** - kube-state-metrics, postgres-exporter, victoria-metrics-agent

### 🔧 Priority 3: Fix Existing Issues
1. **apps-gpt-api** - Fix degraded status
2. **apps-cxs-onenote-auth** - Fix OutOfSync status

### 📊 Priority 4: Standardization
1. Update deprecated `patchesStrategicMerge` patterns to JSON patches
2. Standardize image tag management using `images:` field
3. Complete Fleet infrastructure removal

## Migration Steps for Each Workload

### Pattern 1: Converting Helm to Kustomize (New Workloads)

1. Document current Helm configuration:
   ```bash
   helm get values <chart-name> -n <namespace> > values.yaml
   helm get manifest <chart-name> -n <namespace> > manifests.yaml
   ```

2. Create directory structure:
   ```bash
   mkdir -p <namespace>/<service>/base
   mkdir -p <namespace>/<service>/overlays/production
   mkdir -p <namespace>/<service>/overlays/staging
   ```

3. Convert manifests to base resources:
   ```yaml
   # <namespace>/<service>/base/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   resources:
     - deployment.yaml
     - service.yaml
     - configmap.yaml
   ```

4. Create production overlay:
   ```yaml
   # <namespace>/<service>/overlays/production/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   resources:
     - ../../base
   
   images:
     - name: <image-name>
       newTag: <production-tag>
   
   patches:
     - target:
         kind: Deployment
         name: <service-name>
       patch: |-
         - op: replace
           path: /spec/replicas
           value: 3
   ```

### Pattern 2: Adding Staging Overlays (Existing Apps)

1. Create staging overlay:
   ```yaml
   # apps/<service>/overlays/staging/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   resources:
     - ../../base
   
   namespace: <staging-namespace>
   
   patches:
     - target:
         kind: Deployment
         name: <service-name>
       patch: |-
         - op: replace
           path: /spec/replicas
           value: 1
         - op: replace
           path: /spec/template/spec/containers/0/resources/requests/cpu
           value: "50m"
         - op: replace
           path: /spec/template/spec/containers/0/resources/requests/memory
           value: "128Mi"
   ```

## Testing and Validation

After restructuring each workload:

1. Validate kustomize build for both environments:
   ```bash
   kubectl kustomize <path>/overlays/production
   kubectl kustomize <path>/overlays/staging
   ```

2. Test in staging first:
   ```bash
   kubectl apply --dry-run=client -k <path>/overlays/staging
   kubectl apply -k <path>/overlays/staging
   ```

3. Verify application functionality before production deployment



## Success Metrics

- [ ] **Apps Structure**: 21/21 apps have base/overlay structure
- [ ] **Staging Coverage**: 21/21 apps have staging overlays  
- [ ] **Argo CD Deployment**: 25+ applications (current 19 + 4 Helm migrations + 2 missing apps)
- [ ] **Application Health**: 100% applications Synced/Healthy
- [ ] **Helm Migration**: 0 application workloads managed by Helm
- [ ] **Pattern Standardization**: All apps use modern JSON patches
- [ ] **Fleet Cleanup**: Fleet infrastructure completely removed

**Current Status**: 20/25 expected final applications completed (80%) 