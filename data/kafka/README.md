# Custom setup values for Kafka for QL

We use the default Kafka image from the Bitnami helm chart. (See [Further Reading](#further-reading) below.)

## Versions

| File                        | Environment |
|-----------------------------|-------------|
| [kafka.prod.values.yaml]()  | prod        |
| [kafka.stage.values.yaml]() | staging     |
| **not needed**              | dev         |

## Overrides
A list of the override values and their purpose.
*These are changes that we made to the default values.yaml file.*

Staging:
- `zookeeperChrootPath: "kafka-staging"` # Use the default zookeeper path for prod (Change to /kafka-staging for staging)

Prod:
- `replicaCount: 3` # Increase the number of replicas to 3
- `heapOpts: -Xmx16048m -Xms2024m` # Increase the max heap size to 8GB
- `resourcesPreset: large` # Set a preset profile or define resources

## Setup
1. open a kubectl shell
2. copy the right (dev,staging,prod) file to zookeeper.values.yaml (uses authentication)
    - The 'kafka.yaml' file can be created manually or using the following github way
    - Remember to replace the 'YOUR-ACCESS-TOKEN-HERE' text with your access token
    - `wget --no-cache --no-cookies https://raw.githubusercontent.com/smartdataHQ/cxs/main/data/kafka/kafka.prod.yaml -O kafka.yaml`
    - *may require editing create+copy+save it in place, to create the file*

## Manual Installation Steps

1. Add the helm repo and verify:
2. Update the repo:
3. Visually verify that the images are in the repo
4. Install the chart:
5. Verify the installation:

1. `helm repo add bitnami https://charts.bitnami.com/bitnami`
2. `helm repo update`
3. `helm search repo bitnami/kafka`
4. `helm install kafka bitnami/kafka --namespace data -f kafka.yaml`
5. `kubectl get pods -l app.kubernetes.io/instance=kafka`

#### IMPORTANT
The zookeeper cluster should be available on: `kafka.data.svc.cluster.local:2181`
You can assign an external IP to it in Rancher.


## Further Reading
- [Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/kafka)

## Exemple Output

*The following info can also be found in Rancher* [Exmaple URL](https://ops.quicklookup.com/dashboard/c/c-m-vf2ghkxg/apps/catalog.cattle.io.app/default/kafka#notes)

Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:

kafka.default.svc.cluster.local
Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:

kafka-0.kafka-headless.default.svc.cluster.local:9092
kafka-1.kafka-headless.default.svc.cluster.local:9092
kafka-2.kafka-headless.default.svc.cluster.local:9092
To create a pod that you can use as a Kafka client run the following commands:

kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.5.0-debian-11-r4 --namespace default --command -- sleep infinity
kubectl exec --tty -i kafka-client --namespace default -- bash

PRODUCER:
kafka-console-producer.sh \
--broker-list kafka-0.kafka-headless.default.svc.cluster.local:9092,kafka-1.kafka-headless.default.svc.cluster.local:9092,kafka-2.kafka-headless.default.svc.cluster.local:9092 \
--topic test

CONSUMER:
kafka-console-consumer.sh \
--bootstrap-server kafka.default.svc.cluster.local:9092 \
--topic test \
--from-beginning

