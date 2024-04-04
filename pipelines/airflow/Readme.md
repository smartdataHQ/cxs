## Deploy Airflow (Kubernetes Executor) using Rancher Fleet for Bytewax Pipelines
![Diagram](https://airflow.apache.org/docs/apache-airflow/stable/_images/arch-diag-kubernetes.png)

`helm repo add airflow-stable https://airflow-helm.github.io/charts`

`helm repo update`

## Create namespace
`kubectl create ns pipelines`

## Generate public and private keys for git sync provider 
`ssh-keygen -t rsa -b 4096 -C "your-mail@gmail.com"`
## Add the public key to repository settings deploy keys

## Create private key as a secret
`kubectl create secret generic airflow-ssh-git-secret --from-file=id_rsa=~/.ssh/airflow_ssh_key --namespace airflow-k8s`

## Build custom docker image with bytewax dependencies in pipelines repository
`docker build -f .\Airflow -t airflow:bytewax-2.7.3 .`

## Configure gmail SMTP for email on failure alert

## In gmail settings select Forwarding and POP/IMAP tab and update status to enable in IMAP access 
## Enable 2-Factor authentication for your gmail account
## visit `https://myaccount.google.com/apppasswords` to create a secure password

## Configure sendgrid SMTP for email on failure alert

## Create a account at `https://sendgrid.com
## In dashboard go to settings select sender authentication verify a single sender if status is not verified 
## In Email Api select Integration guide and choose SMTP relay and generate API key
## airflow-smtp-smtp-user secret value is 'apikey' for sendgrid SMTP

## Configure external postgres database
```
CREATE DATABASE airflow_postgres_db;
CREATE USER airflow_postgres_user WITH PASSWORD 'airflow_postgres_password';
GRANT ALL PRIVILEGES ON DATABASE airflow_postgres_db TO airflow_postgres_user;
```
## Connect to airflow_db to run query;
```
GRANT ALL ON SCHEMA public TO airflow_postgres_user;
```
## Create postgres password as a secret
`kubectl create secret generic airflow-postgres-password --from-literal="value=airflow_postgres_password" --namespace pipelines`

## Create Secrets
```
kubectl create secret generic airflow-core-fernet-key --from-literal="value=uuid" --namespace pipelines
kubectl create secret generic airflow-webserver-secret-key --from-literal="value=uuid" --namespace pipelines
kubectl create secret generic airflow-smtp-smtp-mail-from --from-literal="value=example@gmail.com" --namespace pipelines
kubectl create secret generic airflow-smtp-smtp-user --from-literal="value=apikey" --namespace pipelines
kubectl create secret generic airflow-smtp-smtp-password --from-literal="value=password" --namespace pipelines
kubectl create secret generic redis-password --from-literal="value=" --namespace pipelines
kubectl create secret generic postgres-password --from-literal="value=password" --namespace pipelines
kubectl create secret generic clickhouse-password --from-literal="value=password" --namespace pipelines
kubectl create secret generic wod-auth --from-literal="value=password" --namespace pipelines
```
s
## Deploy using fleet
```
kubectl apply -f .\deploy.yaml
```
## View dashboard
`kubectl port-forward svc/airflow-web 8080:8080 --namespace pipelines

