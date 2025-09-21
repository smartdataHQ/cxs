
# Cluster core preparation

Do what needs to be done to prepare a cluster for storage.

Add localdata = true to the cluster machines that support local data storage 

 - `sudo sysctl -w fs.inotify.max_user_instances=512`

## label data nodes that have disc storage

## Create local disc storage for direct disc access for all databases

make sure tha the root directory has the right privileges
```shell
sudo mkdir -p /data/local/clickhouse
sudo mkdir -p /data/local/postgres
sudo mkdir -p /data/local/neo4j
sudo mkdir -p /data/local/solr
sudo mkdir -p /data/local/keeper
chmod -R 0777 /data
```

## Create Ice storage (Slow local storage)
This is slow local (elastic) storage that is expected to be faster than S3 
```shell 
sudo mkdir -p /data/elastic/clickhouse
 chmod -R 0777 /data/elastic
```

## S3 storage created for extra slow storage
This is a local path that can be mapped to a S3 local storage
Using: https://github.com/s3fs-fuse/s3fs-fuse
Follow these instructions for effortless mounting: https://stackoverflow.com/questions/58743636/aws-s3-bucket-is-not-remounting-after-restarting-ec2-instance
```shell
sudo mkdir -p /data/s3/
sudo mkdir -p /data/s3/documents
sudo mkdir -p /data/s3/ingress
chmod -R 0777 /data/s3
```
## S3 mapped to local storage
 
### Setup
```shell
sudo apt-get install s3fs
echo *02:*QU > /etc/passwd-documents-s3fs
echo *03:*QU > /etc/passwd-ingress-s3fs
chmod 0600 /etc/passwd-*
```

### Manual and fstab mounting
```shell
 s3fs cxs-documents /data/s3/documents -o passwd_file=/etc/passwd-documents-s3fs -o url=https://s3.us-west-004.backblazeb2.com/ -o use_path_request_style
 cxs-documents /data/s3/documents fuse.s3fs _netdev,allow_other,use_path_request_style,passwd_file=/etc/passwd-documents-s3fs,url=https://s3.us-west-004.backblazeb2.com/ 0 0
 uid=500,gid=501 (add this to ExecStart for user control above)
```
### Service based mounting
```shell
 sudo vim /usr/lib/systemd/system/s3-ingress.service
```
Contents:
```
[Unit]
Description=Mount S3 Bucket cxs-ingress
Wants=network-online.target
After=network.target network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart = /usr/bin/s3fs cxs-ingress /data/s3/ingress/ -o use_cache=/tmp,passwd_file=/etc/passwd-ingress-s3fs,url=https://s3.us-west-004.backblazeb2.com/
ExecStop=/bin/umount /data/s3/ingress

[Install]
WantedBy = multi-user.target
```

```shell
ln -sf /usr/lib/systemd/system/s3-ingress.service /etc/systemd/system/multi-user.target.wants/s3-ingress.service
systemctl enable s3-ingress.service
systemctl start s3-ingress.service
```


```shell  
sudo vim /usr/lib/systemd/system/s3-documents.service
```
Contents:
```
[Unit]
Description=Mount S3 Bucket cxs-documents
Wants=network-online.target
After=network.target network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart = /usr/bin/s3fs cxs-documents /data/s3/documents/ -o use_cache=/tmp,passwd_file=/etc/passwd-documents-s3fs,url=https://s3.us-west-004.backblazeb2.com/
ExecStop=/bin/umount /data/s3/documents

[Install]
WantedBy = multi-user.target
```

---

```shell
ln -sf /usr/lib/systemd/system/s3-documents.service /etc/systemd/system/multi-user.target.wants/s3-documents.service
systemctl enable s3-documents.service
systemctl start s3-documents.service
```

### postgres
```shell
export POSTGRES_PASSWORD=$(kubectl get secret --namespace data postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
echo $POSTGRES_PASSWORD

kubectl run postgresql-client --rm --tty -i --restart='Never' --namespace data --image docker.io/bitnami/postgresql:16.2.0-debian-12-r10 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
--command -- psql --host postgresql -U postgres -d postgres -p 5432

kubectl port-forward --namespace data svc/postgresql 5432:5432 & PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

### Certificate
```shell
kubectl -n ingress-nginx create secret tls ingress-default-cert --cert=contextsuite.com.cert --key=contextsuite.com.key -o yaml --dry-run=true > ingress-default-cert.yaml
```


### Zookeeper

`zookeeper.data.svc.cluster.local`
`2181`
```shell
export POD_NAME=$(kubectl get pods --namespace data -l "app.kubernetes.io/name=zookeeper,app.kubernetes.io/instance=zookeeper,app.kubernetes.io/component=zookeeper" -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD_NAME -- zkCli.sh

kubectl port-forward --namespace data svc/zookeeper 2181:2181 & zkCli.sh 127.0.0.1:2181
```


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


