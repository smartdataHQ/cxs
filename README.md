# CXS Platform GitOps Deployment

This repository contains the configuration for our Kubernetes clusters and the services that run on them. We utilize a GitOps approach, where this repository is the single source of truth for our infrastructure and application deployments.

## Project Purpose and Architecture

The primary purpose of this project is to manage the deployment and configuration of platform solutions and their associated backend services. Our architecture relies on the following key technologies:

*   **Kubernetes:** An open-source system for automating deployment, scaling, and management of containerized applications.
*   **Rancher:** A platform for managing multiple Kubernetes clusters. We use Rancher to oversee all our clusters, regardless of the underlying cloud provider.
*   **Fleet:** A GitOps tool by Rancher that monitors this repository. When changes are pushed to this repository, Fleet automatically detects them and applies the necessary updates to the respective Kubernetes clusters. This ensures that our deployed infrastructure and applications always reflect the state defined in this repository.
*   **Helm:** A package manager for Kubernetes that allows us to define, install, and upgrade even the most complex Kubernetes applications using charts. We use Helm to package and deploy our services.
*   **Docker Hub:** We store our container images in Docker Hub. Our CI/CD pipelines (primarily Github Actions) build our application code, containerize it into Docker images, and push these images to Docker Hub. Fleet then fetches these images based on the tags specified in the deployment configurations within this repository.

The overall workflow is as follows:
1.  Application code is developed and pushed to its respective Github repository.
2.  Github Actions build the code, create a Docker image, and push it to Docker Hub.
3.  Configuration changes for deployments (e.g., updating an image tag, changing resource limits, or deploying a new service) are made in this repository.
4.  Fleet detects these changes and applies them to the target Kubernetes cluster, pulling the specified Docker images from Docker Hub and deploying them according to the Helm charts and other Kubernetes manifests.

### Index

- [Project Purpose and Architecture](#project-purpose-and-architecture)
- [Directory Structure](#directory-structure)
- [Development Environment and Contribution](#development-environment-and-contribution)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Data Storage](#data-storage)
- [Authentication](#authentication)
- [Version Policy](#version-policy)
- [Root-Level Deployment System](#root-level-deployment-system)
- [First Principles and Directives](#first-principles-and-directives)
- [Systems involved and their roles](#systems-involved-and-their-roles)
  - [Github](#github)
  - [Rancher](#rancher)
  - [Docker Hub](#docker-hub)
  

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
*   `apps/`: Contains the Kubernetes manifests (deployments, services, etc.) and Fleet configuration for application solutions. Each solution typically has a `base/` directory for common Kustomize configurations and an `overlays/` directory for environment-specific configurations (e.g., `production`, `staging`).
*   `authentication/`: Configuration related to authentication mechanisms, currently housing Tailscale setup via Fleet.
*   `data/`: Contains configurations for our data stores and related services, such as ClickHouse, Kafka, Neo4j, PostgreSQL, Solr, and object storage mappings (e.g., `c00dbmappings` for S3). It also includes documentation and deployment files for these services.
*   `db_restore/`: Scripts and configuration files related to database restore procedures.
*   `monitoring/`: Configuration for our monitoring stack, including Grafana for dashboards and alerting, Loki for log aggregation, and Prometheus service monitors.
*   `operators/`: Kubernetes operators that extend the functionality of our clusters, such as Cert-Manager for managing TLS certificates and OpenTelemetry (otel) for observability.
*   `pipelines/`: Configuration for data pipelines and workflow automation tools like Apache Airflow and Apache NiFi.
*   `FIRST_PRINCIPLES.md`: Core principles and directives that guide all technical decisions and implementations.

## Environments: dev, staging, production

We maintain three variants of the same tech stack with consistent patterns across environments. Development is optimized for Rancher Desktop, while staging and production follow hardened best practices.

### dev (Rancher Desktop)
- Target runtime: Rancher Desktop with containerd
- Overlays: `overlays/dev` for each solution
- Image policy: `imagePullPolicy: Never` for local images; tags like `dev-latest`
- Scale: single replica, minimal resources
- Access: port-forward by default; optional dev ingress using `*.localtest.me`
- Secrets: create local K8s Secrets from `.env.local` (no secrets in git)

### staging
- Mirrors production topology at smaller scale
- Image policy: immutable, pinned tags; `imagePullPolicy: Always`
- TLS and ingress on staging subdomains
- Uses Rancher-managed Secrets (ESO adoption planned)

### production
- Pinned, immutable image tags
- Resource requests/limits and autoscaling
- Readiness/liveness probes; PodSecurity, NetworkPolicies
- Encrypted secrets, TLS everywhere, backups/restore procedures
- Strict RBAC and change controls

### Safety rails
- Cluster labels: `env=dev|staging|production` and Fleet `targetCustomizations` ensure overlays deploy only to intended clusters
- Protected branches and reviews required for staging/production changes

Note: Root-level scripts are intended for dev on Rancher Desktop. Staging and production are applied by Fleet via environment overlays.

## Refactor plan (2025): one solution at a time

We are refactoring solutions incrementally to the tri-environment pattern. We will migrate one solution at a time, while keeping staging and production requirements in mind from the outset.

High-level steps per solution:
- Create/update `base/` to be environment-agnostic
- Add `overlays/dev|staging|production` with appropriate scaling, tags, and policies
- Extend `fleet.yaml` with `targetCustomizations` for env selectors
- Provide `.env.example`, `deploy-dev.sh`, `test-connection.sh`, `cleanup-dev.sh`
- Validate with Rancher Desktop (dev) and a staging cluster before promoting

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

### Deployment strategy: Kustomize-first
- Author resources in `base/` with environment-agnostic manifests.
- Apply environment differences only via `overlays/dev|staging|production`.
- Use Fleet `targetCustomizations` to select overlays by cluster labels for staging/production.
- Keep shell scripts as thin dev helpers (secrets, local testing, port-forwarding).
- No env-specific imperative logic in scripts; use `kubectl kustomize` / `-k` exclusively for apply.

### Testing policy: minimal tooling
- Prefer ephemeral tests using `kubectl run` with official images (e.g., `postgres:16-alpine`) to verify connectivity.
- Do not add client libraries/binaries to this repository.
- Per-solution `test-connection.sh` owns its test; the root `test-connections.sh` only delegates.
- Always use `--rm` for ephemeral test pods so they are removed automatically when tests complete.

### Data layer high-availability (production)
- For persistence/data solutions (databases, queues, search, etc.), production must be highly available: **3 or more nodes is the bare minimum**.
- Achieve HA using the appropriate technology (operators like Percona/Crunchy for PostgreSQL, native clustering for Kafka/Solr, or managed services). Do not scale a single-container `Deployment` for stateful HA.
- Dev uses a simple single-instance container for simplicity; staging mirrors production patterns at smaller scale; production enforces HA, pinned images, and strict policies.

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

## Version Policy

All development instances of solutions in the CXS platform use the latest stable version of their underlying technologies to ensure developers are working with up-to-date features and security patches. See `docs/solution-version-policy.md`.

## Root-Level Deployment System

We have implemented a "Super Simple Docker-Compose" for Kubernetes approach that enables frictionless developer onboarding and service orchestration. This system provides:

*   **Single Entry Point:** One `.env` file and one script at the root to deploy any combination of services
*   **Service Cherry-Picking:** Enable/disable entire services via simple flags in the root `.env` file
*   **Minimal Configuration:** Only essential settings in root `.env`, everything else uses sane defaults
*   **Progressive Expansion:** Start simple, add more services over time as they're migrated
*   **Backwards Compatibility:** Existing individual service deployments still work

For details on this system, see [ROOT_DEPLOYMENT_SYSTEM.md](ROOT_DEPLOYMENT_SYSTEM.md).

### Root .env contract (dev-only)
The root `.env` enables cherry-picking services and sets global dev passwords. It is parsed by a shared loader that also reads `.env.local` for developer overrides.

Order of precedence:
1. Defaults in loader
2. Values from `.env`
3. Overrides from `.env.local`

Keys:
- `ENABLE_*` service toggles (e.g., `ENABLE_POSTGRES=true`)
- `GLOBAL_ADMIN_PASSWORD`, `GLOBAL_APP_PASSWORD` (used by services as defaults)
 - Optional remote endpoints (prefer remote over local deploys/tests when set):
   - `REMOTE_POSTGRES_HOST`, `REMOTE_POSTGRES_PORT`, `REMOTE_POSTGRES_USER`, `REMOTE_POSTGRES_PASSWORD`
   - `REMOTE_KAFKA_BROKERS` (comma-separated), `REMOTE_CLICKHOUSE_HOST`, `REMOTE_CLICKHOUSE_PORT`, `REMOTE_NEO4J_URI`

Service-specific overrides can be defined in local service `.env` files if needed, but services should prefer the global values for simplicity.

#### Remote services (dev convenience)
Developers can point apps to shared remote databases/queues by setting the `REMOTE_*` variables above. When a remote is configured, local deployment for that service is skipped, and test scripts validate against the remote endpoint instead.

Example:
```bash
ENABLE_POSTGRES=false
REMOTE_POSTGRES_HOST=db.dev.example.com
REMOTE_POSTGRES_PORT=5432
REMOTE_POSTGRES_USER=postgres
REMOTE_POSTGRES_PASSWORD=changeme
```

## First Principles and Directives

The fundamental principles and directives that guide the design, development, and maintenance of the CXS platform are documented in [FIRST_PRINCIPLES.md](FIRST_PRINCIPLES.md). This document outlines the core first principles including Simplicity Above All, Developer Experience First, Progressive Enhancement, Backwards Compatibility, and Declarative Infrastructure.

## Systems involved and their roles
The following systems are involved in deploying platform services.

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

 - See [kubevpn](https://github.com/kubenetworks/kubevpn/releases)
 - [Install client](https://github.com/kubenetworks/kubevpn/releases)
 - make the script executable: `chmod +x Download/kubevpn.sh`
 - Login and download KubeConfig from the [CxS Rancher](https://ops.quicklookup.com/)
 - connect: `kubevpn/bin/kubevpn connect -n data --kubeconfig Downloads/cxs-eu1.yaml`
 - disconnect: `kubevpn/bin/kubevpn disconnect`


 