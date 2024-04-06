# Custom setup values for AirflowNeo4j for QL


## Setup
1. open a kubectl shell
2. copy the right (dev,staging,prod) file to zookeeper.values.yaml (uses authentication)
    - Remember to replace the 'YOUR-ACCESS-TOKEN-HERE' text with your access token
    - `wget https://raw.githubusercontent.com/smartdataHQ/cxs/main/pipelines/airflow/values.yaml -O values.yaml`
    - *may require editing create+copy+save it in place, to create the file*

    
1. `helm repo add airflow https://airflow-helm.github.io/charts`
2. `helm repo update`
3. `helm search repo airflow/`
4. `helm install airflow airflow/airflow --namespace pipelines -f values.yaml`
5. `kubectl get pods -l app.kubernetes.io/instance=airflow`

## Configure Access
NAME: airflow
LAST DEPLOYED: Sat Apr  6 14:38:09 2024
NAMESPACE: pipelines
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
========================================================================
Thanks for deploying Apache Airflow with the User-Community Helm Chart!

====================
TIPS
====================
Default Airflow Webserver login:
* Username:  admin
* Password:  admin

You have NOT set up persistence for worker task logs, do this by:
1. Using a PersistentVolumeClaim with `logs.persistence.*`
2. Using remote logging with `AIRFLOW__LOGGING__REMOTE_LOGGING`

It looks like you have NOT exposed the Airflow Webserver, do this by:
1. Using a Kubernetes Ingress with `ingress.*`
2. Using a Kubernetes LoadBalancer/NodePort type Service with `web.service.type`

Use these commands to port-forward the Services to your localhost:
* Airflow Webserver:  kubectl port-forward svc/airflow-web 8080:8080 --namespace pipelines

========================================================================