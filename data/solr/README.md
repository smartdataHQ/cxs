https://artifacthub.io/packages/helm/apache-solr/solr?modal=install
https://apache.github.io/solr-operator/docs/running-the-operator
https://apache.github.io/solr-operator/docs/solr-cloud/solr-cloud-crd.html#override-built-in-solr-configuration-files

https://solr.apache.org/operator/articles/explore-v030-gke.html

helm repo add apache-solr https://solr.apache.org/charts
helm repo update
kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.8.0/all-with-dependencies.yaml -n data
helm install solr-operator apache-solr/solr-operator --version 0.8.0 -n data

## older
``
https://solr.apache.org/operator/articles/explore-v030-gke.html
helm repo add apache-solr https://solr.apache.org/charts
helm repo update
kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.3.0/all-with-dependencies.yaml
helm upgrade --install solr-operator apache-solr/solr-operator --version 0.3.0
``