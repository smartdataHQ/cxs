# Kafka (Bitnami Helm Chart)

## Purpose
Provides a distributed event streaming platform. Used for building real-time data pipelines and streaming applications within the project. We use the default Kafka image from the Bitnami helm chart.

## Configuration
- Configuration is managed via Helm values files, such as `kafka.prod.yaml` for the production environment. These files define overrides for the default Bitnami Kafka Helm chart.
- Secrets (like SASL user credentials) are managed in Rancher and injected at deployment time. Refer to the main project `README.md` for more details on secret management.
- The original README mentioned different values files per environment (e.g., `kafka.stage.values.yaml`), which should be maintained if still in use.

Key override examples from the original README:
-   **Staging:** `zookeeperChrootPath: "kafka-staging"`
-   **Prod:** `replicaCount: 3`, `heapOpts: -Xmx16048m -Xms2024m`, `resourcesPreset: large` (Note: Using `resourcesPreset` is not recommended for production; specific resource requests/limits should be set).

## Deployment
- Kafka is deployed via Fleet, which uses the Helm chart and the environment-specific values files (e.g., `kafka.prod.yaml`) to install and manage the Kafka cluster.
- The Zookeeper cluster, a dependency for Kafka, should be available at `kafka.data.svc.cluster.local:2181` (internal cluster DNS).

## Backup and Restore
[Details on backup and restore procedures for Kafka need to be added. This typically involves strategies for backing up topic data, consumer offsets, and configurations. Tools like MirrorMaker or custom snapshot solutions might be used.]

## Manual Installation & Client Connection (from original README)

These instructions were part of the original README and are preserved for reference. However, primary deployment is managed by Fleet.

### Setup
1.  Open a kubectl shell.
2.  Prepare the appropriate values file (e.g., `kafka.prod.yaml`).
    *   Example: `wget --no-cache --no-cookies https://raw.githubusercontent.com/smartdataHQ/cxs/main/data/kafka/kafka.prod.yaml -O kafka.yaml` (Ensure the URL and token are correct if used).

### Manual Helm Installation Steps
1.  `helm repo add bitnami https://charts.bitnami.com/bitnami`
2.  `helm repo update`
3.  `helm search repo bitnami/kafka` (Visually verify images)
4.  `helm install kafka bitnami/kafka --namespace data -f kafka.yaml` (Replace `kafka.yaml` with the correct values file)
5.  `kubectl get pods -l app.kubernetes.io/instance=kafka` (Verify installation)

### Connecting a Client
Kafka can be accessed by consumers via port 9092 on `kafka.data.svc.cluster.local`.
Broker-specific DNS names are also available (e.g., `kafka-broker-0.kafka-broker-headless.data.svc.cluster.local:9092`).

Client configuration (`client.properties`):
```properties
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
username="user1" \
password="$(kubectl get secret kafka-user-passwords --namespace data -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";
```

Example client pod and commands:
```bash
kubectl run kafka-client --restart='Never' --image docker.io/bitnamilegacy/kafka:3.7.0-debian-12-r0 --namespace data --command -- sleep infinity
kubectl cp --namespace data /path/to/client.properties kafka-client:/tmp/client.properties
kubectl exec --tty -i kafka-client --namespace data -- bash

# PRODUCER:
kafka-console-producer.sh \
    --producer.config /tmp/client.properties \
    --broker-list kafka-broker-0.kafka-broker-headless.data.svc.cluster.local:9092,kafka-broker-1.kafka-broker-headless.data.svc.cluster.local:9092,kafka-broker-2.kafka-broker-headless.data.svc.cluster.local:9092 \
    --topic test

# CONSUMER:
kafka-console-consumer.sh \
    --consumer.config /tmp/client.properties \
    --bootstrap-server kafka.data.svc.cluster.local:9092 \
    --topic test \
    --from-beginning
```

## Key Files
- `fleet.yaml`: (Assumed, as per project standard, though not explicitly listed in `ls data/kafka/`) Fleet configuration for deployment.
- `kafka.prod.yaml`: Helm values file for the production Kafka deployment. (Other environment-specific values files like `kafka.stage.values.yaml` might exist).
- `README.md`: This file.

## Further Reading
- [Bitnami Kafka Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/kafka)
