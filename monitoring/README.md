# Install datadog agent
```
helm repo add datadog https://helm.datadoghq.com 
helm install datadog-operator datadog/datadog-operator
kubectl create secret generic datadog-secret --from-literal api-key=<api-key> --from-literal app-key=<app-key>-n pipelines
kubectl apply -f deployment.yaml -n pipelines
```

# Airflow Integrtion update airflow.config in values.yaml
```
AIRFLOW__METRICS__STATSD_ON: true
AIRFLOW__METRICS__STATSD_HOST: <hostname>
AIRFLOW__METRICS__STATSD_PORT: "8125"
AIRFLOW__METRICS__STATSD_PREFIX: "airflow"
AIRFLOW__METRICS__STATSD_DATADOG_ENABLED: true
AIRFLOW__METRICS__STATSD_ALLOW_LIST: "executor"
AIRFLOW__METRICS__STATSD_DATADOG_TAGS: "statsd_group:airflow,statsd_env:pipelines"
```
