# Apache Solr

## Purpose
Provides an open-source enterprise search platform built on Apache Lucene. Used for full-text search capabilities and indexing large volumes of data. This deployment is managed using the Solr Operator.

## Configuration
- **Operator Based:** SolrCloud clusters are defined and configured via a `SolrCloud` Custom Resource (CR) managed by the Solr Operator.
- **Instance Configuration:**
    - `solr.yaml`: May contain the base `SolrCloud` Custom Resource definition or other core configurations for the Solr cluster.
    - `solr.prod.yaml`: Likely an environment-specific values file or patch for production, possibly used by Kustomize or directly by Fleet.
- **Kustomize:** `kustomization.yaml` suggests that Kustomize is used to manage environment-specific configurations or customizations for the Solr deployment.
- **Secrets:** Any sensitive information (e.g., credentials for accessing Solr if security features are enabled) should be managed in Rancher and injected at deployment time. Refer to the main project `README.md`.

## Deployment and Management
- **Fleet:** Solr is deployed and managed via Fleet, as specified in `fleet.yaml`. Fleet likely applies the Kustomize configurations which would include the Solr Operator Custom Resources.
- **Solr Operator:** The operator handles the lifecycle management of SolrCloud clusters. The original notes section contains commands for installing the operator.

## Backup and Restore
[Details on backup and restore procedures for Solr need to be added. This typically involves:
- Using Solr's Collections API for taking snapshots of collections.
- Backing up the underlying PersistentVolumes where Solr data (indexes, transaction logs) is stored.
- If an external Zookeeper is used, backing up its data as well.]

## Key Files
- `fleet.yaml`: Fleet configuration for Solr deployment.
- `solr.yaml`: Potentially contains the base `SolrCloud` Custom Resource definition or other core Solr configurations.
- `solr.prod.yaml`: Environment-specific values or patches for the Solr deployment.
- `kustomization.yaml`: Kustomize configuration for managing Solr resources.
- `README.md`: This file.

## Original Notes (for reference)
The following commands and links were in the previous version of this README, related to operator installation:

- **Links:**
    - https://artifacthub.io/packages/helm/apache-solr/solr?modal=install
    - https://apache.github.io/solr-operator/docs/running-the-operator
    - https://apache.github.io/solr-operator/docs/solr-cloud/solr-cloud-crd.html#override-built-in-solr-configuration-files
    - https://solr.apache.org/operator/articles/explore-v030-gke.html (Older version link)

- **Operator Installation (v0.8.0 example):**
    ```bash
    helm repo add apache-solr https://solr.apache.org/charts
    helm repo update
    kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.8.0/all-with-dependencies.yaml -n data
    helm install solr-operator apache-solr/solr-operator --version 0.8.0 -n data
    ```

- **Older Operator Installation (v0.3.0 example):**
    ```bash
    # https://solr.apache.org/operator/articles/explore-v030-gke.html (Link for context)
    helm repo add apache-solr https://solr.apache.org/charts
    helm repo update
    kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.3.0/all-with-dependencies.yaml
    helm upgrade --install solr-operator apache-solr/solr-operator --version 0.3.0
    ```
