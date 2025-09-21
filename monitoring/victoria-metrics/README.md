# Victoria Metrics Agent

## Prerequisits

### Create a secret 
Create a required secret in namespace `monitoring` with a name `observation-basic-auth`. 

```bash
# example-secret.yaml file

apiVersion: v1
kind: Secret
metadata:
  name: observation-basic-auth
  namespace: monitoring
stringData:
  username: xxx-username
  password: xxx-password
```

```bash
kubectl apply -f example-secret.yaml -n monitoring
```