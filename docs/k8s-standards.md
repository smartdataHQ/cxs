# CXS Kubernetes Standards and Environment Guidelines

This document defines how we structure Kubernetes, Kustomize, and Rancher Fleet configuration across dev, staging, and production. It is designed to be applied incrementally without disrupting the current production setup.

## Goals
- Consistent, environment-agnostic bases with clean environment overlays
- Zero change to current production by default
- Local developer workflow with Rancher Desktop
- Secrets managed safely with a phased path to External Secrets for stage/prod

## Environments and naming
- Environments: `dev` (local), `staging` (shared pre-prod), `production`
- Overlays: `overlays/dev`, `overlays/staging`, `overlays/production`
- Cluster label for Fleet selection: `env=dev|staging|production`
  - Note: Some existing Fleet bundles use `role=production`. We will keep those in place and add new `env`-based targetCustomizations as we migrate. Production stays unchanged until we explicitly switch.
- Namespaces: keep existing domains (e.g., `api`, `data`, `pipelines`, `ingress`)
- Resource names: do not suffix object names with `-dev`/`-staging`; differentiate by namespace, labels, and overlay config. Use `env: <dev|staging|production>` and, if needed, `app.kubernetes.io/instance: <service>` for selectors.
- Common labels (applied via Kustomize):
  - `app: <service-name>`
  - `tier: <api|worker|frontend|...>`
  - `env: <dev|staging|production>` (set in overlays)

## Repository structure (per solution)
```
apps/<solution>/
  base/               # environment-agnostic manifests
  overlays/
    dev/              # local developer config
    staging/          # pre-prod config
    production/       # existing production config
  fleet.yaml          # Fleet bundle targeting overlays per env
```
Likewise under `data/` and other top-level groups.

## Kustomize conventions
- `base/` contains Deployments, Services, ConfigMaps, Jobs, CRDs references, etc. No env-specific values (replicas, hosts, image tags).
- `overlays/<env>` apply environment-specific patches:
  - image tags and pull policy
  - replicas and autoscaling
  - resource requests/limits
  - ingress hosts, annotations
  - logging levels and feature flags via ConfigMap
- Prefer JSON 6902 patches for precise edits; use `patchStrategicMerge` for simple merges

### Kustomize-first policy
- Base manifests carry no environment-specific values
- All env differences (replicas, resources, tags, ingress) live in overlays
- Fleet selects overlays by cluster labels; no manual script-based applies in staging/prod
- Dev helper scripts may create Secrets and run tests, but must apply manifests via `kubectl kustomize`/`-k`

### Testing policy (dev/stage/prod)
- Use ephemeral pods via `kubectl run` with official client images for connectivity checks
- Avoid adding language runtimes or client libraries to this repo
- Own tests per solution; aggregate runner only delegates
- Ensure test pods are deleted after completion (`--rm`); do not leave test workloads running
- Example: minimal dev overlay
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
images:
  - name: quicklookup/<service>
    newTag: dev-latest
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/replicas
        value: 1
      - op: add
        path: /spec/template/spec/containers/0/imagePullPolicy
        value: Never
configMapGenerator:
  - name: <service>-config
    behavior: merge
    literals:
      - LOG_LEVEL=debug
```

## Image tagging and pull policy
- dev: `:<branch-or-dev-latest>`, `imagePullPolicy: Never` (for local images)
- staging/prod: immutable tags (Git SHA or release), `imagePullPolicy: Always`

## Ingress and service exposure
- dev: default to port-forwarding for simplicity; optionally enable ingress with local hostnames (`*.localtest.me`, `127.0.0.1.nip.io`) when needed. Dev overlays must expose container ports and define a ClusterIP Service so port-forwarding works out of the box.
- staging/prod: standard DNS (`app.staging.example.com`, `app.example.com`), TLS via cluster issuer

## Probes policy by environment
- dev: readiness/liveness probes may be relaxed (higher timeouts/failure thresholds) to avoid false restarts on slow local machines; terminationGracePeriodSeconds may be increased. Prefer stability over strictness.
- staging/prod: keep strict probes and production-grade timings; failures must surface quickly.

## Rancher Fleet patterns
- Each bundle’s `fleet.yaml` defines `targetCustomizations` by environment:
```yaml
# Example
# production (existing)
- name: production
  clusterSelector:
    matchLabels:
      role: production
  kustomize:
    dir: overlays/production

# new staging
- name: staging
  clusterSelector:
    matchLabels:
      env: staging
  kustomize:
    dir: overlays/staging

# optional dev (only if you have a shared dev cluster)
- name: dev
  clusterSelector:
    matchLabels:
      env: dev
  kustomize:
    dir: overlays/dev
```
- For Helm-based stacks, use `helm.valuesFiles` per env, or maintain `values-<env>.yaml` and select via `targetCustomizations`
- Keep each environment’s target isolated; do not change production selectors in this phase


## Secret store strategy (planned standard)
- Planned provider: Azure Key Vault
- Region: Sweden Central
- Vault name: Moonshot
- Integration: External Secrets Operator (ESO) on Rancher-managed clusters.
- Status: Deferred. We currently use Rancher-managed Kubernetes Secrets across all environments; ESO adoption will come later without changing current production.


Current practice (all envs):
- Secrets are created and managed directly in the cluster via Rancher UI/automation
- Manifests reference Secret names/keys only (no values in git)
- For local dev, create Secrets from .env.local using `make dev-secrets`

## Secrets policy
- Do not commit secrets to git
- Baseline (all envs): enable encryption at rest for Kubernetes Secrets (KMS-backed if available), and enforce least-privilege RBAC
 - Dev (local): all per-solution dev secrets must be sourced from the repository root `.env`/`.env.local`. Each solution’s `deploy-dev.sh` must materialize a Kubernetes Secret from these values before applying manifests. Do not hardcode passwords in manifests.
 - Staging/Production: never source secrets from `.env`. Manage secrets in-cluster (Rancher/Kubernetes Secrets now; External Secrets Operator later). Manifests reference Secret names/keys only.

### Installing External Secrets Operator (ESO) with Azure Key Vault [planned]

This section is deferred. Keep using Rancher-managed Kubernetes Secrets for now. The guidance below can be applied later without altering current production. It describes how to deploy ESO and integrate it with Azure Key Vault "Moonshot" (Sweden Central) using Rancher Fleet. Preferred auth is Azure AD Workload Identity on AKS; a Service Principal fallback is also shown.

#### Option A: Azure AD Workload Identity (recommended on AKS)
High-level steps:
1) Enable OIDC issuer and Workload Identity on the AKS cluster.
2) Create a User-Assigned Managed Identity (UAMI) in Sweden Central.
3) Grant the UAMI data-plane access to the Key Vault (RBAC: Key Vault Secrets User or finer-grained role).
4) Create a Federated Identity Credential on the UAMI for the Kubernetes ServiceAccount subject:
   - subject: `system:serviceaccount:external-secrets:eso-azure-wi`
   - issuer: the AKS OIDC issuer URL
5) Annotate the ServiceAccount with the UAMI client ID.

Fleet bundle to install ESO and ServiceAccount (example):

```yaml
# platform/external-secrets/fleet.yaml
defaultNamespace: external-secrets
helm:
  chart: external-secrets
  repo: https://charts.external-secrets.io
  # Pin a compatible version; example shown
  version: 0.10.6
  values:
    installCRDs: true
    serviceAccount:
      create: true
      name: eso-azure-wi
      annotations:
        azure.workload.identity/client-id: <UAMI_CLIENT_ID>
```

ClusterSecretStore referencing Azure Key Vault via Workload Identity:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-moonshot
spec:
  provider:
    azurekv:
      tenantId: <AZURE_TENANT_ID>
      vaultUrl: https://Moonshot.vault.azure.net/
      authType: WorkloadIdentity
      serviceAccountRef:
        name: eso-azure-wi
        namespace: external-secrets
```

#### Option B: Service Principal (interim fallback)
Create an App Registration with a client secret; grant it Key Vault data-plane access. Store the SP credentials in a Kubernetes Secret in `external-secrets` namespace, then reference it from the SecretStore.

Kubernetes Secret containing SP credentials:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: azure-sp
  namespace: external-secrets
stringData:
  client-id: <APP_CLIENT_ID>
  client-secret: <APP_CLIENT_SECRET>
```

ClusterSecretStore using Service Principal:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-moonshot
spec:
  provider:
    azurekv:
      tenantId: <AZURE_TENANT_ID>
      vaultUrl: https://Moonshot.vault.azure.net/
      authType: ServicePrincipal
      authSecretRef:
        clientId:
          name: azure-sp
          key: client-id
          namespace: external-secrets
        clientSecret:
          name: azure-sp
          key: client-secret
          namespace: external-secrets
```

#### Using secrets in workloads
Define an ExternalSecret in the workload namespace; ESO will materialize a Kubernetes Secret consumed by your Deployment.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: inbox-secrets
  namespace: inbox
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-moonshot
    kind: ClusterSecretStore
  target:
    name: inbox-secrets
    creationPolicy: Owner
  data:
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: inbox-POSTGRES_PASSWORD
    - secretKey: NEO4J_PASSWORD
      remoteRef:
        key: inbox_NEO4J_PASSWORD
```

Notes:
- `remoteRef.key` must match the Secret name in Azure Key Vault.
- Prefer Azure RBAC for Key Vault with the minimal roles needed.
- For non-AKS clusters, use Service Principal until Workload Identity is supported.

- Stage/Prod (recommended): adopt External Secrets Operator (ESO) to source from a managed secret store (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, HashiCorp Vault, 1Password, etc.)
  - Fleet deploys ESO CRDs/operator once per cluster or via a platform bundle
  - Application overlays define `ExternalSecret` resources; ESO writes K8s Secrets consumed by Pods
- Dev (local): generate K8s Secrets from a local `.env.local` via a simple script/Make target (non-sensitive dev defaults only)
- Alternative (optionally evaluated next): Secrets Store CSI Driver to mount secrets at runtime (with optional sync to K8s Secrets)
- SOPS-based approaches are viable with a SOPS controller; not required initially

## Local developer workflow (Rancher Desktop)
Prerequisites:
- Rancher Desktop with containerd enabled
- `nerdctl`, `kubectl`, `kustomize` (or `kubectl kustomize`)

Typical loop:
1) Build image locally:
   - `nerdctl build -t quicklookup/<service>:dev-latest .`
2) Apply dev overlay:

### Data namespace: developer cherry-pick workflow
- Developers should only run the minimum set of data services needed for their task. Almost no developer needs the full data stack locally.
- Each data component will have a dev overlay (added incrementally). Apply only those you need, for example:
  - `kustomize build data/neo4j/overlays/dev | kubectl apply -f -`
  - `kustomize build data/postgres/overlays/dev | kubectl apply -f -`
  - `kustomize build data/kafkaui/overlays/dev | kubectl apply -f -`
- Access locally via port-forwarding (preferred), or enable dev ingress per component when available.
- Secrets: continue to use Rancher-managed Secret names/keys; for local dev, create placeholders:
  - `make dev-secrets NAMESPACE=data NAME=<secret-name> FILE=.env.local`
- Cleanup when done:
  - `kubectl delete -k data/<component>/overlays/dev`
### Remote service usage (dev)
- Developers may set `REMOTE_*` variables in root `.env` to point to shared services (e.g., remote PostgreSQL, Kafka).
- When a `REMOTE_*` is set, local deployment for that service is skipped; connection tests target the remote endpoint.
- Keep credentials in `.env.local` where possible; do not commit any `.env` files.


   - `kustomize build apps/<service>/overlays/dev | kubectl apply -f -`
3) Create dev secrets (once per service):
   - `.env.local` -> `kubectl create secret generic <service>-secrets --from-env-file=.env.local -n <namespace>`
4) Namespace creation: Dev scripts ensure the `data` namespace exists automatically.

5) Access app:
   - `kubectl port-forward deploy/<service> 8080:80 -n <namespace>`
   - or enable dev ingress with local hostnames

Note: A starter template is available at `docs/env.example`. Copy and adjust as needed.

## Best practices (all environments)
- Containers run as non-root with minimal capabilities; set `securityContext` appropriately
- Define readiness and liveness probes for all Deployments
- Resource requests/limits defined in staging/production; autoscaling where appropriate
- Use NetworkPolicies to restrict pod-to-pod communication
- Enforce TLS for all ingress; use cluster issuers in staging/production
- Immutable, pinned image tags for staging/production; avoid `latest`
- Centralized logging (Loki) and metrics (Prometheus); dashboards and alerts in Grafana
- Backup/restore plans for data services with tested runbooks
- No secrets in git; use Rancher-managed Secrets now; plan ESO later
- JVM-based services: explicitly set heap via env (e.g., `JAVA_TOOL_OPTIONS` or service-specific like `SOLR_JAVA_MEM`); keep `-Xmx` ≤ ~60% of the container memory limit, and set `-Xms` to match for stability. For dev on Rancher Desktop, start with `-Xms1g -Xmx1g` and requests/limits around `1Gi/2Gi`, then tune as needed.
- JVM shutdown: increase `terminationGracePeriodSeconds` (e.g., 60s) to allow graceful shutdown and avoid SIGKILL during index flush/close.

## Data layer HA policy (production)
- Persistence/data solutions (e.g., PostgreSQL, Kafka, ClickHouse, Solr, Neo4j) must be highly available in production: **minimum 3 nodes**.
- Use the right primitives:
  - Databases: operators or managed services (not multi-replica Deployments)
  - Queues/search/OLAP: native clustering/replication topologies
- Dev: single instance for simplicity; staging: scaled-down but topology-aligned; prod: full HA, pinned images, probes, NetworkPolicies, PDBs.

## Migration playbook (incremental, safe-by-default)
1) Create `overlays/dev` and `overlays/staging` for a pilot service
2) Extend its `fleet.yaml` with `staging` (and optional `dev`) targetCustomizations
3) Verify dev locally (Rancher Desktop), then a staging deployment on a staging cluster
4) Document per-service specifics in `apps/<service>/README.md`
5) Repeat for additional services

## Policy checklist
- [ ] No secrets in git
- [ ] `env` label used by new Fleet targetCustomizations
- [ ] Production untouched until explicitly changed
- [ ] Dev overlay sets `imagePullPolicy: Never`, `replicas: 1`
- [ ] Staging overlay mirrors prod with smaller resources and staging hostnames
- [ ] Common labels applied; consistent naming across envs

## FAQ: Does Rancher support these secret solutions?
- Kubernetes Secrets: Yes, fully supported
- External Secrets Operator: Yes. ESO is a standard K8s operator that runs on Rancher-managed clusters; install via Helm/Fleet. ESO supports major backends (AWS/GCP/Azure/Vault/1Password, etc.)
- Secrets Store CSI Driver: Yes. Install the driver and a provider (e.g., Azure Key Vault Provider, AWS Secrets & Config Provider, GCP, Vault) via Helm/Fleet; supported on Rancher-managed clusters
- SOPS-based workflows: Supported via adding a SOPS controller (or Flux + SOPS). Fleet can deploy these components, but does not decrypt SOPS by itself; either use a controller or pre-decrypt in CI

## Appendix: hostnames
- dev: `*.localtest.me` or `127.0.0.1.nip.io`
- staging: `app.staging.<your-domain>`
- production: `app.<your-domain>`

