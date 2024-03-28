
Postgres Operator
https://github.com/zalando/postgres-operator/blob/master/docs/quickstart.md#deployment-options

#Steps
### add repo for postgres-operator
`helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator`
`helm install postgres-operator postgres-operator-charts/postgres-operator --namespace data`

To verify that postgres-operator has started, run:
kubectl --namespace=default get pods -l "app.kubernetes.io/name=postgres-operator"

### add repo for postgres-operator-ui
`helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui`

### install the postgres-operator-ui
`helm install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui --namespace data`

To verify that postgres-operator has started, run:
kubectl --namespace=default get pods -l "app.kubernetes.io/name=postgres-operator-ui"