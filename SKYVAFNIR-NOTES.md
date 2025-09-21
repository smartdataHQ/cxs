# Rancher Setup

This is a guide to setting up Rancher on a new local cluster.

The aim is to expose and configuration (pain)points that might arise.

## Prerequisites
- Access to Rancher (https://ops.quicklookup.com)
- Docker for Desktop (tested on MacOs)
- Helm
- Kubectl

## Steps
1. Enable Kubernetes in Docker for Desktop in the D4D preferences.
1. Wait for the cluster to be ready.
1. Log into Rancher and create a new cluster.
1. Ensure your kubeconfig is pointing to the new cluster.
1. Copy the `kubectl` command from the Rancher UI and run it in your terminal. It should look something like this:
   ```shell
   $ kubectl apply -f https://ops.quicklookup.com/v3/import/<super random string>.yaml
   ```
1. Wait for the cluster to show up in the Rancher UI.


## Context Suite Work Log

### Postgres Operator
See: [data/postgres/README.md](data/postgres/README.md)

### Clickhouse

Install Clickhouse inside the cluster for testing via a Operator

There is an operator: https://github.com/Altinity/clickhouse-operator/blob/master/docs/quick_start.md#prerequisites

Let's use that.

**Install the clickhouse operator**
```shell
$ kubectl apply -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/deploy/operator/clickhouse-operator-install-bundle.yaml
```

**Instantiate a Clickhouse cluster**
```shell
$ kubectl create ns clickhouse && kubectl delete -n clickhouse -f https://raw.githubusercontent.com/Altinity/clickhouse-operator/master/docs/chi-examples/01-simple-layout-01-1shard-1repl.yaml
```

```.yaml
apiVersion: "clickhouse.altinity.com/v1"
kind: "ClickHouseInstallation"
metadata:
  name: "clickhouse"
spec:
  configuration:
    users:
      # printf 'test_password' | sha256sum
      test_user/password_sha256_hex: 10a6e6cc8311a3e2bcc09bf6c199adecd5dd59408c343e926b129c4914f3cb01
      test_user/password: test_password
      # to allow access outside from kubernetes
      test_user/networks/ip:
        - 0.0.0.0/0
    clusters:
      - name: "clickhouse"
```

Be sure to update clickhouse user/pass in context-api CM and Secret with something like the following:
```
# This is in the ConfigMap:
CLICKHOUSE_USER=test_user
CLICKHOUSE_CONNECTION=http://clickhouse-clickhouse.clickhouse:8123

# This is in the Secret:
CLICKHOUSE_PASSWORD=test_password
```


### Redis

Redis is running in the `data` Namespace. Seems orphaned. Not in the rancher repo at least. According to annotations and labels
it was installed via helm, but how?

Let's go with helm for now.
```shell
$ helm install -ndata redis oci://registry-1.docker.io/bitnamicharts/redis
```

Fetch the password
```shell
$ kubectl get secret --namespace data redis -o jsonpath="{.data.redis-password}"
```

and update the `contextapi` Secret with the secret:
```shell
REDIS_PASSWORD=<SECRET FROM PREVIOUS STEP>
```
