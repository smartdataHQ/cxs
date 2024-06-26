# Custom setup values for Neo4j for QL

We use the default neo4j image from the Bitnami helm chart. (See [Further Reading](#further-reading) below.)

## Versions

| File                       | Environment |
|----------------------------|-------------|
| [neo4j.prod.values.yaml]() | prod        |
| **not needed**             | staging     |
| **not needed**             | dev         |

## Overrides
A list of the override values and their purpose.</br>
*These are changes that we made to the default values.yaml file.*

Prod:
- `name: "neo4j"`
- `password: "qldevpass"` # We need a much better way to handle this
- `edition: "enterprise"` # to match the license
- `acceptLicenseAgreement: "yes"` # to accept the license
- `volumns: "dynamic"` # many changes and cleanup of alternative storage configs
- `apoc.trigger.enabled: "true"` # to enable apoc triggers
- `apoc.jdbc.apoctest.url: "jdbc:foo:bar"` 
- Various disk volumn settings to mount the backup-pvc claim to the /tmp/backup folder

## Setup
1. open a kubectl shell
2. copy the right (dev,staging,prod) file to zookeeper.values.yaml (uses authentication)
   - Remember to replace the 'YOUR-ACCESS-TOKEN-HERE' text with your access token
   - `wget https://raw.githubusercontent.com/smartdataHQ/cxs/main/data/neo4j/neo4j.prod.values.yaml -O neo4j.values.yaml`
   - *may require editing create+copy+save it in place, to create the file*


## Special Considerations
We are using both the apoc and apoc extended libraries.</br>
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