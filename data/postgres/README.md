
https://www.percona.com/blog/easy-way-to-provision-a-postgresql-cluster-on-kubernetes/

kubectl create namespace postgres-operator

kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml -n data

kubectl apply -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/cr.yaml -n data

add external IP to pgbouncer services


cxs-pg-pguser-cxs-pg

PGBOUNCER_URI=$(kubectl get secret cxs-pg-pguser-cxs-pg --namespace data -o jsonpath='{.data.pgbouncer-uri}' | base64 --decode)

kubectl run -i --rm --tty pg-client --image=perconalab/percona-distribution-postgresql:16 --restart=Never -- psql $PGBOUNCER_URI
