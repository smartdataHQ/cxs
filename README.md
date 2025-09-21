# Quick Lookup and Context Suite Deployment

This repository contains the configuration for our Kubernetes clusters and the services that run on them. We utilize a GitOps approach, where this repository is the single source of truth for our infrastructure and application deployments.

## Project Purpose and Architecture

The primary purpose of this project is to manage the deployment and configuration of the **Quick Lookup and Context Suite** applications and their associated backend services. Our architecture relies on the following key technologies:

*   **Kubernetes:** An open-source system for automating deployment, scaling, and management of containerized applications.
*   **ArgoCD:** A declarative GitOps continuous delivery tool for Kubernetes that synchronizes application state from this Git repository to our clusters. ArgoCD has replaced Fleet as our GitOps engine. See [argocd/README.md](argocd/README.md) for detailed information about our ArgoCD setup and workflow.
*   **Rancher:** A platform for managing multiple Kubernetes clusters. We use Rancher to oversee all our clusters, regardless of the underlying cloud provider.
*   **Helm:** A package manager for Kubernetes that allows us to define, install, and upgrade even the most complex Kubernetes applications using charts. We use Helm to package and deploy our services.
*   **Docker Hub:** We store our container images in Docker Hub. Our CI/CD pipelines (primarily Github Actions) build our application code, containerize it into Docker images, and push these images to Docker Hub. ArgoCD then fetches these images based on the tags specified in the deployment configurations within this repository.

The overall workflow is as follows:
1.  Application code is developed and pushed to its respective Github repository.
2.  Github Actions build the code, create a Docker image, and push it to Docker Hub.
3.  Configuration changes for deployments (e.g., updating an image tag, changing resource limits, or deploying a new service) are made in this repository.
4.  ArgoCD detects these changes and applies them to the target Kubernetes cluster, pulling the specified Docker images from Docker Hub and deploying them according to the Helm charts and other Kubernetes manifests.

### Index

- [Project Purpose and Architecture](#project-purpose-and-architecture)
- [Directory Structure](#directory-structure)
- [Development Environment and Contribution](#development-environment-and-contribution)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Data Storage](#data-storage)
- [Authentication](#authentication)
- [Systems involved and their roles](#systems-involved-and-their-roles)
  - [Github](#github)
  - [Rancher](#rancher)
  - [Docker Hub](#docker-hub)
- [Applications included in repo](#applications-included-in-repo)
  - [Context Suite](#context-suite)
    - [The Client Application](#the-client-application)
    - [The Context API](#the-context-api)
  - [Quick Lookup](#quick-lookup)
    - [The Graph API](#the-graph-api)
    - [The Bestlist](#the-bestlist)
  - [Self Services Portal](#self-services-portal)
  - [The GraphQL Playground](#the-graphql-playground)

### IMPORTANT!
**No secrets are stored in this repo. NONE AT ALL!**</br>
As this is a public repo, all secrets are stored in Rancher and injected into the cluster at deployment time.
Before you commit any changes to this repo, make sure you have removed all secrets from the files you are changing.

Refer to the [Rancher documentation](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-resources-setup/secrets#docusaurus_skipToContent_fallback) for how to add secrets to the cluster.

### Also IMPORTANT!
We separate deployment configuration from application code.</br>
The only CI actions included in code repos are building, dockerizing the code and pushing the image to DockerHub.</br>
All other deployment configuration is stored in this repo.

## Directory Structure

This repository is organized as follows:

*   `README.md`: This file, providing an overview of the project.
*   `VPN.md`: Documentation related to VPN setup using Tailscale.
*   `ansible/`: Infrastructure automation and monitoring setup for bare-metal servers using Ansible playbooks and roles.
*   `apps/`: Contains the Kubernetes manifests (deployments, services, etc.) and ArgoCD configuration for all our applications (e.g., Context API, Context Suite, Quick Lookup components). Each application typically has a `base/` directory for common Kustomize configurations and an `overlays/` directory for environment-specific configurations (e.g., `production`, `staging`).
*   `appsets/`: ArgoCD ApplicationSet definitions that automatically discover and create Applications based on directory structure patterns.
*   `argocd/`: ArgoCD deployment configuration and documentation. See `argocd/README.md` for detailed GitOps workflow information.
*   `data/`: Contains configurations for our data stores and related services, such as ClickHouse, Kafka, Neo4j, PostgreSQL, Redis, and backup configurations. It also includes documentation and deployment files for these services.
*   `db_restore/`: Scripts and configuration files related to database restore procedures.
*   `docs/`: Documentation including infrastructure analysis, migration plans, and operational guides.
*   `migration-plan/`: Specific documentation and planning materials for infrastructure migrations.
*   `monitoring/`: Configuration for our monitoring stack, including Grafana for dashboards and alerting, Loki for log aggregation, Prometheus service monitors, and data layer monitoring.
*   `operators/`: Kubernetes operators that extend the functionality of our clusters, such as Cert-Manager for managing TLS certificates and OpenTelemetry (otel) for observability.
*   `pipelines/`: Configuration for data pipelines and workflow automation tools like Apache Airflow.
*   `scripts/`: Utility scripts for various operational tasks and automation.

## Development Environment and Contribution

As this repository primarily stores configuration files (YAML for Kubernetes, Helm, Fleet), a standard development environment with a text editor (like VS Code with YAML support) and Git is usually sufficient.

To contribute:

1.  **Understand the GitOps Workflow:** All changes to infrastructure and application deployments are managed through this repository.
2.  **Separate Code and Configuration:** Application code resides in its own repositories. This repository is solely for deployment configuration.
3.  **Branching Strategy:** Create a new branch for your changes.
4.  **Make Changes:** Modify or add configuration files as needed.
    *   Ensure you are not committing any secrets. Secrets are managed externally in Rancher.
    *   Follow the existing directory structure and Kustomize patterns where applicable.
5.  **Test (if applicable):** For complex changes, consider testing in a staging or development environment if available.
6.  **Commit and Push:** Use clear commit messages.
7.  **Create a Pull Request:** Describe your changes in the pull request for review.
8.  **Review and Merge:** Once reviewed and approved, changes will be merged, and Fleet will automatically apply them to the clusters.

Github Actions are configured in the respective application code repositories to build Docker images and push them to Docker Hub. This repository then references these images for deployment.

## Deployment

Deployment is managed through **Fleet**, Rancher's GitOps engine. Fleet monitors this Git repository for any changes to the defined state of our Kubernetes clusters.

*   **Helm Charts:** We use Helm to package our applications. Helm charts define all the necessary Kubernetes resources (Deployments, Services, ConfigMaps, etc.) for an application. These charts are often stored within the `apps/` subdirectories or referenced from external Helm repositories.
*   **Kustomize:** We use Kustomize to manage environment-specific configurations. `base/` directories contain common configurations, and `overlays/` (e.g., `overlays/production`, `overlays/staging`) customize these for specific environments.
*   **Fleet Configuration (`fleet.yaml`):** Each application or component managed by Fleet has a `fleet.yaml` file. This file tells Fleet which paths in the repository to monitor, which target clusters or cluster groups to deploy to, and other deployment-related settings.

When changes are merged into the main branch of this repository:
1.  Fleet detects the changes.
2.  Fleet processes the relevant Helm charts, Kustomize overlays, and Kubernetes manifests.
3.  Fleet applies these configurations to the designated Kubernetes clusters, ensuring the deployed state matches the state defined in Git.

## Monitoring

Our monitoring stack primarily consists of:

*   **Grafana:** Used for visualizing metrics, creating dashboards, and setting up alerts. We have various dashboards to monitor the health and performance of our applications and infrastructure. Grafana configurations and alert rules can be found in the `monitoring/grafana/` directory.
*   **Loki:** A horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus. Loki is used to collect and query logs from all our services running in Kubernetes. Configuration for Loki can be found in `monitoring/grafana-loki/`.
*   **Prometheus:** While not explicitly detailed in the file structure for its core components, Prometheus is often used in conjunction with Grafana. ServiceMonitors (defined in `monitoring/service-monitors/`) are used to tell Prometheus how to scrape metrics from our services.
*   **Grafana Alloy (formerly Promtail):** Used for collecting logs and forwarding them to Loki. Configurations are in `monitoring/grafana-alloy/`.

## Data Storage

We utilize a variety of data stores depending on the needs of our applications:

*   **PostgreSQL:** A powerful open-source object-relational database system. Used for structured data storage for various applications. Configuration and backup jobs are in `data/postgres/`.
*   **ClickHouse:** A fast open-source column-oriented database management system for online analytical processing (OLAP). Used for analytics and large-scale data queries. See `data/clickhouse/`.
*   **Neo4j:** A graph database management system. Used for applications that require managing and querying highly connected data. See `data/neo4j/`.
*   **Solr:** An open-source enterprise search platform built on Apache Lucene. Used for full-text search capabilities. See `data/solr/`.
*   **Kafka:** A distributed event streaming platform. Used for building real-time data pipelines and streaming applications. See `data/kafka/` and `data/kafka-schema-registry/`.
*   **S3-compatible Object Storage:** Used for storing large binary objects, such as customer documents. The `README.md` previously mentioned `s3fs` for mounting S3 buckets, and `data/c00dbmappings/` likely relates to configurations for accessing these stores.
*   **Vault:** Used for managing secrets. See `data/vault/`.
*   **Cube:** Business intelligence (BI) platform. See `data/cube/`.
*   **Keeper:** Potentially another secrets manager or data store, configurations are in `data/keeper/`.
*   **n8n:** Workflow automation tool, which might have its own data storage requirements. See `data/n8n/`.

The `data/` directory contains specific configurations, Helm charts, and Fleet deployment files for these data services.

## Authentication

Primary authentication and secure access to our internal resources and clusters are managed through **Tailscale**.

*   **Tailscale:** A VPN service that creates a secure network between our servers, development machines, and other resources. It allows us to access devices and services as if they were on the same local network, regardless of their physical location.
*   **VPN Access to Clusters:** While the `README.md` previously mentioned `kubevpn` for direct Kubernetes VPN access, Tailscale provides a more comprehensive network mesh.
*   **Routing:** Specific routes can be advertised through Tailscale to allow access to external protected resources via a static IP address, ensuring secure and controlled connections. The `VPN.md` file contains details on how routes are managed and how to set up Tailscale on hosts.
*   **Fleet Configuration:** Tailscale configuration within this repository (`authentication/tailscale/`) likely manages the deployment or configuration of Tailscale-related resources within the cluster, if any, or acts as a placeholder for its documentation.

Refer to the `VPN.md` file for detailed instructions on Tailscale setup and route management.

## Systems involved and their roles
The following systems are involved in deploying Quick Lookup and Context Suite services.

### Github
This repository is stored on Github and contains all configuration for the services and applications.
When it changes, Fleet will automatically deploy the changes to the cluster.

Our code is also stored in Github and is automatically built and dockerized by Github Actions.
Docker images are then stored in [DockerHub](#docker-hub).

### Rancher
We use Rancher to manage all of our Kubernetes clusters, independent of the cloud provider.
Fleet is the part of Rancher that is used to monitor and deploy the configuration in this repo.

Our rancher instance is available at [ops.quicklookup.com](https://ops.quicklookup.com)
[Rancher Docs](https://ranchermanager.docs.rancher.com/)
[Fleet Docs](https://fleet.rancher.io/)

### Docker Hub
We store container images in DockerHub.
Fleet fetches the images from DockerHub and deploys them to the cluster based on the tags specified in this repo.
We can have Github Actions updated these tags automatically when code is pushed to Github.

[Our DockerHub Repo](https://hub.docker.com/repository/docker/quicklookup/)

# S3 mount S3 point for customer documents
This section was previously in the README, providing instructions for mounting S3 buckets. This functionality is generally related to data storage.

 - `sudo apt install s3fs`
 - `echo ACCESS_KEY_ID:SECRET_ACCESS_KEY > ${HOME}/.passwd-s3fs`
 - `chmod 600 ${HOME}/.passwd-s3fs`
 - `s3fs mybucket /path/to/mountpoint -o passwd_file=${HOME}/.passwd-s3fs -o url=https://url.to.s3/ -o use_path_request_style`
 - Add to `/etc/fstab`: `mybucket /path/to/mountpoint fuse.s3fs _netdev,allow_other,use_path_request_style,url=https://url.to.s3/ 0 0`

# VPN Access to the Cluster
This section was previously in the README. For current VPN information, please refer to the [Authentication](#authentication) section and the `VPN.md` file.

 - See [kubevpn](https://github.com/kubenetworks/kubevpn)
 - [Install client](https://github.com/kubenetworks/kubevpn/releases)
 - make the script executable: `chmod +x Download/kubevpn.sh`
 - Login and download KubeConfig from the [CxS Rancher](https://ops.quicklookup.com/)
 - connect: `kubevpn/bin/kubevpn connect -n data --kubeconfig Downloads/cxs-eu1.yaml`
 - disconnect: `kubevpn/bin/kubevpn disconnect`


# Applications included in repo

This section lists the high-level applications managed in this repository. More detailed information about each application, including its specific purpose, configuration, and Kubernetes resources, can be found in the `README.md` file within its respective directory under `apps/`.

## Context Suite

### The Client Application

### The Context API

## Quick Lookup

### The Graph API

### The Bestlist

## Self Services Portal

## The GraphQL Playground
