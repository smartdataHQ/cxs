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

** Please be patient while the chart is being deployed **

Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:

    kafka.data.svc.cluster.local

Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:

    kafka-broker-0.kafka-broker-headless.data.svc.cluster.local:9092
    kafka-broker-1.kafka-broker-headless.data.svc.cluster.local:9092
    kafka-broker-2.kafka-broker-headless.data.svc.cluster.local:9092

The CLIENT listener for Kafka client connections from within your cluster have been configured with the following security settings:
- SASL authentication

To connect a client to your Kafka, you need to create the 'client.properties' configuration files with the content below:

security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="user1" \
password="$(kubectl get secret kafka-user-passwords --namespace data -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";

To create a pod that you can use as a Kafka client run the following commands:

    kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.7.0-debian-12-r0 --namespace data --command -- sleep infinity
    kubectl cp --namespace data /path/to/client.properties kafka-client:/tmp/client.properties
    kubectl exec --tty -i kafka-client --namespace data -- bash

    PRODUCER:
        kafka-console-producer.sh \
            --producer.config /tmp/client.properties \
            --broker-list kafka-broker-0.kafka-broker-headless.data.svc.cluster.local:9092,kafka-broker-1.kafka-broker-headless.data.svc.cluster.local:9092,kafka-broker-2.kafka-broker-headless.data.svc.cluster.local:9092 \
            --topic test

    CONSUMER:
        kafka-console-consumer.sh \
            --consumer.config /tmp/client.properties \
            --bootstrap-server kafka.data.svc.cluster.local:9092 \
            --topic test \
            --from-beginning

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
- broker.resources
  +info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
