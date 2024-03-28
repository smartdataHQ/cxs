
https://www.percona.com/blog/easy-way-to-provision-a-postgresql-cluster-on-kubernetes/

kubectl create namespace postgres-operator

kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/bundle.yaml -n data

kubectl apply -f https://raw.githubusercontent.com/percona/percona-postgresql-operator/v2.3.1/deploy/cr.yaml -n data