-- postgres
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
echo $POSTGRES_PASSWORD

kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace data --image docker.io/bitnami/postgresql:16.2.0-debian-12-r10 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
--command -- psql --host postgresql -U postgres -d postgres -p 5432

kubectl port-forward --namespace data svc/postgresql 5432:5432 & PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432


--- Certification
kubectl -n ingress-nginx create secret tls ingress-default-cert --cert=contextsuite.com.cert --key=contextsuite.com.key -o yaml --dry-run=true > ingress-default-cert.yaml


--- Zookeeper
zookeeper.data.svc.cluster.local
2181

export POD_NAME=$(kubectl get pods --namespace data -l "app.kubernetes.io/name=zookeeper,app.kubernetes.io/instance=zookeeper,app.kubernetes.io/component=zookeeper" -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD_NAME -- zkCli.sh

kubectl port-forward --namespace data svc/zookeeper 2181:2181 & zkCli.sh 127.0.0.1:2181


--- Redis
redis-master.data.svc.cluster.local for read/write operations (port 6379)
redis-replicas.data.svc.cluster.local for read-only operations (port 6379)

export REDIS_PASSWORD=$(kubectl get secret --namespace data redis -o jsonpath="{.data.redis-password}" | base64 -d)


--- Kafka
Kafka can be accessed by consumers via port 9092 on the following DNS name from within your cluster:

    kafka.data.svc.cluster.local

Each Kafka broker can be accessed by producers via port 9092 on the following DNS name(s) from within your cluster:

    kafka-controller-0.kafka-controller-headless.data.svc.cluster.local:9092
    kafka-controller-1.kafka-controller-headless.data.svc.cluster.local:9092
    kafka-controller-2.kafka-controller-headless.data.svc.cluster.local:9092

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
            --broker-list kafka-controller-0.kafka-controller-headless.data.svc.cluster.local:9092,kafka-controller-1.kafka-controller-headless.data.svc.cluster.local:9092,kafka-controller-2.kafka-controller-headless.data.svc.cluster.local:9092 \
            --topic test

    CONSUMER:
        kafka-console-consumer.sh \
            --consumer.config /tmp/client.properties \
            --bootstrap-server kafka.data.svc.cluster.local:9092 \
            --topic test \
            --from-beginning
>