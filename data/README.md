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