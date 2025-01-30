# Installing the Percona Postgres Operator
_(https://www.percona.com/blog/easy-way-to-provision-a-postgresql-cluster-on-kubernetes/)_
Run:
```shell
kubectl create namespace postgres-operator \
&& kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml -n data
```

Rancher **should** be able to provision the `perconapgcluster.pgv2.percona.com` / `pg` Custom Resource for us now.

## add external IP to pgbouncer services
_I'm not sure what this means._

## Test that the operator has provisioned our db
```
# Secret Name: cxs-pg-pguser-cxs-pg
export PGBOUNCER_URI=$(kubectl get secret cxs-pg-pguser-cxs-pg --namespace data -o jsonpath='{.data.pgbouncer-uri}' | base64 --decode) \
&& kubectl run -i --rm --tty pg-client --image=perconalab/percona-distribution-postgresql:16 --restart=Never -- psql $PGBOUNCER_URI
```