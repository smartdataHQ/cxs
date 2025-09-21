# PostgreSQL Metrics Exporter

## Prerequisits

### Create a secret 
Create a required secret in namespace `monitoring` with a name `postgres-data`. 

add source of the secret password
add note for creating a dedicated user

```bash
# example-secret.yaml file

apiVersion: v1
kind: Secret
metadata:
  name: postgres-data
  namespace: monitoring
stringData:
  password: xxx-password
```

```bash
kubectl apply -f example-secret.yaml -n monitoring
```

### Configuration via `values.yaml`

Configure postgresql-exporter to connect to your PostgreSQL database.

```yaml
config:
  datasource:
    host: 'cxs-pg-pgbouncer.data.svc'
    user: 'postgres'
    port: '5432'
    sslmode: require
    passwordSecret:
      name: 'postgres-data'
      key: 'password'
```