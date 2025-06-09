# Neo4j Graph Database

## Purpose
Provides a native graph database management system, used for applications that require managing and querying highly connected data. This deployment is configured to use the enterprise edition of Neo4j. It appears to use the official Neo4j Helm chart.

## Configuration
- **Primary Configuration:** Managed via Helm values files, specifically `neo4j.prod.values.yaml` for the production environment. This file defines overrides for the Helm chart.
- **Secrets Management:**
    - The original README notes `password: "qldevpass"` and warns about storing passwords in plain text, recommending `neo4j.passwordFromSecret`.
    - **Standard Practice:** All secrets, including Neo4j passwords, must be managed in Rancher and injected securely at deployment time. Refer to the main project `README.md` for general guidance on secret management.
- **Neo4j Edition:** Configured for "enterprise" edition, which requires a valid license (`acceptLicenseAgreement: "yes"`).
- **APOC Plugins:** APOC (Awesome Procedures On Cypher) triggers are enabled (`apoc.trigger.enabled: "true"`). Custom setup for APOC and APOC extended libraries is detailed in the "Special Considerations" section.

### Versions (from original README)

| File                       | Environment |
|----------------------------|-------------|
| [neo4j.prod.values.yaml]() | prod        |
| **not needed**             | staging     |
| **not needed**             | dev         |

### Key Overrides from `neo4j.prod.values.yaml` (examples from original README)

Prod:
- `name: "neo4j"`
- `password: "qldevpass"` # We need a much better way to handle this
- `edition: "enterprise"` # to match the license
- `acceptLicenseAgreement: "yes"` # to accept the license
- `volumns: "dynamic"` # many changes and cleanup of alternative storage configs
- `apoc.trigger.enabled: "true"` # to enable apoc triggers
- `apoc.jdbc.apoctest.url: "jdbc:foo:bar"` 
- Various disk volumn settings to mount the backup-pvc claim to the /tmp/backup folder

## Deployment and Management
- **Deployment Method:** Neo4j is deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet utilizes the Helm chart along with the `neo4j.prod.values.yaml` values file.
- **Cluster Access:** The Neo4j instance is accessible within the Kubernetes cluster at `neo4j://neo4j.data.svc.cluster.local:7687`.
- **Kustomize Overlays:** The `overlays/` directory suggests Kustomize might be used for further environment-specific adjustments beyond the Helm values.

## Backup and Restore
- **Mechanism:** The configuration mentions "Various disk volume settings to mount the backup-pvc claim to the /tmp/backup folder," suggesting that backups are facilitated by mounting a persistent volume claim intended for backup storage.
- **Procedures:** [Detailed procedures for performing backups (e.g., using `neo4j-admin backup`) and restoring them (e.g., `neo4j-admin restore`) targeting this `/tmp/backup` directory need to be formally documented. This includes frequency, retention policies, and verification steps.]

## Setup (from original README)
1. open a kubectl shell
2. copy the right (dev,staging,prod) file to zookeeper.values.yaml (uses authentication)
   - Remember to replace the 'YOUR-ACCESS-TOKEN-HERE' text with your access token
   - `wget https://raw.githubusercontent.com/smartdataHQ/cxs/main/data/neo4j/neo4j.prod.values.yaml -O neo4j.values.yaml`
   - *may require editing create+copy+save it in place, to create the file*


## Special Considerations
We are using both the apoc and apoc extended libraries.
Setting them up is a hassle. (Will be documented later.)

Rather than doing this "properly", I ended up doing the following:
1. mount a persistent volume: /tmp/plugins
2. copy plugins manually to there
3. point neo4j to that directory for plugins

Handy:
- `SHOW PROCEDURES yield name, description, signature;` # to list all procedures found in neo4j
- `neo4j restart` # to restart the pod from exec shell

- https://github.com/neo4j/apoc/releases/download/5.9.0/apoc-5.9.0-core.jar
- https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/5.9.0/apoc-5.9.0-extended.jar
- https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/5.9.0/apoc-nlp-dependencies-5.9.0-all.jar

## Manual Installation Steps

1. Add the helm repo and verify:
2. Update the repo:
3. Visually verify that the images are in the repo
4. Install the chart:
5. Verify the installation:

1. `helm repo add neo4j https://helm.neo4j.com/neo4j`
2. `helm repo update`
3. `helm search repo neo4j/`
4. `helm install neo4j neo4j/neo4j --namespace data -f neo4j.values.yaml`
5. `kubectl get pods -l app.kubernetes.io/instance=neo4j`

To upgrade everything:
- `helm upgrade neo4j neo4j/neo4j --namespace default -f neo4j.values.yaml`

- To uninstall everything:
- `helm uninstall neo4j`

## Configure Access
Thank you for installing neo4j.

Your release "neo4j" has been installed  in namespace "data".

The neo4j user's password has been set to "rMUo39i9bymvxp".To view the progress of the rollout try:

$ kubectl --namespace "data" rollout status --watch --timeout=600s statefulset/neo4j

Once rollout is complete you can log in to Neo4j at "neo4j://neo4j.data.svc.cluster.local:7687". Try:

$ kubectl run --rm -it --namespace "data" --image "neo4j:5.18.0-enterprise" cypher-shell -- cypher-shell -a "neo4j://neo4j.data.svc.cluster.local:7687" -u neo4j -p "rMUo39i9bymvxp"

Graphs are everywhere!

WARNING: Passwords set using 'neo4j.password' will be stored in plain text in the Helm release ConfigMap.
Please consider using 'neo4j.passwordFromSecret' for improved security.

## Key Files
- `fleet.yaml`: Fleet configuration for Neo4j deployment.
- `neo4j.prod.values.yaml`: Helm values file for production environment. (Other environment-specific values files might exist).
- `overlays/`: Directory potentially containing Kustomize overlays for further customization.
- `README.md`: This documentation file.