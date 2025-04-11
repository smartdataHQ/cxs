# Migration to new k8s cluster

### Namespaces we shouldn't migrate

#### Empty namespaces _(no resources)_
- cattle-dashboards
- cattle-impersonation-system
- kafka
- local
- openobserve
- openobserve-collector
- opentelemetry-operator-system
- tom
- tommi
- vault
- vector

### List of helm installations

| NAMESPACE | NAME | REVISION | UPDATED | STATUS | CHART | APP VERSION |
|-----------|------|----------|---------|--------|-------|--------------|
| api | csx-deployment-apps-contextapi | 5 | 2025-04-09 19:48:58.954121143 +0000 UTC | deployed | csx-deployment-apps-contextapi-v0.0.0+git-7d145304705f |  |
| api | csx-deployment-apps-formapi | 6 | 2025-04-10 16:47:19.374696949 +0000 UTC | deployed | csx-deployment-apps-formapi-v0.0.0+git-2800eb976a44 |  |
| api | csx-deployment-apps-playground | 2 | 2025-04-09 19:48:58.681362057 +0000 UTC | deployed | csx-deployment-apps-playground-v0.0.0+git-7d145304705f |  |
| api | csx-deployment-apps-ssp | 16 | 2025-04-09 19:48:59.335627768 +0000 UTC | deployed | csx-deployment-apps-ssp-v0.0.0+git-7d145304705f |  |
| cattle-fleet-system | fleet-agent-cxs-eu1 | 408 | 2025-04-10 08:38:30.445808318 +0000 UTC | deployed | fleet-agent-cxs-eu1-v0.0.0+s-9c951a992e1db12eaa5fc7cc340f357a0b00b33d2d31b2304153987342dd3 |  |
| cattle-monitoring-system | rancher-monitoring | 1 | 2024-03-29 04:52:27.109920853 +0000 UTC | deployed | rancher-monitoring-102.0.3+up40.1.2 | 0.59.1 |
| cattle-monitoring-system | rancher-monitoring-crd | 1 | 2024-03-29 04:52:05.808003804 +0000 UTC | deployed | rancher-monitoring-crd-102.0.3+up40.1.2 |  |
| cattle-system | cxs-eu1-managed-system-agent | 1 | 2024-03-27 04:41:47.642648066 +0000 UTC | deployed | cxs-eu1-managed-system-agent-v0.0.0+s-c725d8de9a5a9ff9abb5fe55016ad0803bbe0e19c9b159edb0f086c18d1f5 |  |
| cattle-system | mcc-cxs-eu1-managed-system-upgrade-controller | 1 | 2024-03-27 04:41:35.835698507 +0000 UTC | deployed | system-upgrade-controller-102.1.0+up0.5.0 | v0.11.0 |
| cattle-system | rancher-webhook | 1 | 2024-03-27 04:42:31.277281987 +0000 UTC | deployed | rancher-webhook-2.0.5+up0.3.5 | 0.3.5 |
| cert-manager | csx-deployment-operators-cert-manager | 4 | 2025-04-09 19:49:18.507922999 +0000 UTC | deployed | cert-manager-v1.15.3 | v1.15.3 |
| data | csx-deployment-data-c00dbmappings | 3 | 2025-04-09 19:49:32.50791675 +0000 UTC | deployed | csx-deployment-data-c00dbmappings-v0.0.0+git-7d145304705f |  |
| data | csx-deployment-data-clickhouse | 2 | 2025-04-09 19:49:03.315694798 +0000 UTC | deployed | csx-deployment-data-clickhouse-v0.0.0+git-7d145304705f |  |
| data | csx-deployment-data-cube | 2 | 2025-04-09 19:49:03.493870365 +0000 UTC | deployed | csx-deployment-data-cube-v0.0.0+git-7d145304705f |  |
| data | csx-deployment-data-keeper | 2 | 2025-04-09 19:49:04.576361292 +0000 UTC | deployed | csx-deployment-data-keeper-v0.0.0+git-7d145304705f |  |
| data | csx-deployment-data-neo4j | 3 | 2025-04-09 19:49:30.774534412 +0000 UTC | deployed | csx-deployment-data-neo4j-v0.0.0+git-7d145304705f |  |
| data | csx-deployment-data-postgres | 2 | 2025-04-09 19:49:07.494179188 +0000 UTC | deployed | csx-deployment-data-postgres-v0.0.0+git-7d145304705f |  |
| data | kafka-schema-registry | 2 | 2025-04-09 19:49:04.42990297 +0000 UTC | deployed | cp-schema-registry-0.1.0 | 1.0 |
| data | solr-operator | 2 | 2025-04-09 19:49:09.722113441 +0000 UTC | deployed | solr-operator-0.8.1 | v0.8.1 |
| data | vault | 2 | 2025-04-09 19:49:08.234663601 +0000 UTC | deployed | vault-0.29.1 | 1.18.1 |
| default | csx-deployment | 177 | 2025-04-10 21:22:34.060728253 +0000 UTC | deployed | csx-deployment-v0.0.0+git-231246ea34f0 |  |
| grafana | alloy | 2 | 2025-04-09 19:49:12.38765607 +0000 UTC | deployed | alloy-0.12.1 | v1.7.1 |
| grafana | csx-deployment-monitoring-grafana | 2 | 2025-04-09 19:49:11.150333244 +0000 UTC | deployed | grafana-8.8.6 | 11.4.1 |
| grafana | loki | 3 | 2025-04-09 19:49:43.720355908 +0000 UTC | deployed | loki-6.27.0 | 3.4.2 |
| ingestion | csx-deployment-apps-isl-hotel-streaming-client | 2 | 2025-04-09 19:48:57.355557334 +0000 UTC | deployed | csx-deployment-apps-isl-hotel-streaming-client-v0.0.0+git-7d145304705f |  |
| ingress | csx-deployment-apps-inbox | 7 | 2025-04-09 19:49:20.565501508 +0000 UTC | deployed | csx-deployment-apps-inbox-v0.0.0+git-7d145304705f |  |
| ingress | csx-deployment-apps-ingress | 3 | 2025-04-09 19:49:22.179514517 +0000 UTC | deployed | csx-deployment-apps-ingress-v0.0.0+git-7d145304705f |  |
| kube-system | rke2-calico | 1 | 2024-03-27 04:39:21.644690371 +0000 UTC | deployed | rke2-calico-v3.27.002 | v3.27.0 |
| kube-system | rke2-calico-crd | 1 | 2024-03-27 04:39:04.551941779 +0000 UTC | deployed | rke2-calico-crd-v3.27.002 |  |
| kube-system | rke2-coredns | 1 | 2024-03-27 04:39:04.545852364 +0000 UTC | deployed | rke2-coredns-1.29.001 | 1.11.1 |
| kube-system | rke2-ingress-nginx | 1 | 2024-03-27 04:40:11.324208295 +0000 UTC | deployed | rke2-ingress-nginx-4.8.200 | 1.9.3 |
| kube-system | rke2-metrics-server | 1 | 2024-03-27 04:40:08.263810407 +0000 UTC | deployed | rke2-metrics-server-2.11.100-build2023051513 | 0.6.3 |
| kube-system | rke2-snapshot-controller | 1 | 2024-03-27 04:40:21.95602871 +0000 UTC | deployed | rke2-snapshot-controller-1.7.202 | v6.2.1 |
| kube-system | rke2-snapshot-controller-crd | 1 | 2024-03-27 04:40:09.255552203 +0000 UTC | deployed | rke2-snapshot-controller-crd-1.7.202 | v6.2.1 |
| kube-system | rke2-snapshot-validation-webhook | 1 | 2024-03-27 04:40:05.53107194 +0000 UTC | deployed | rke2-snapshot-validation-webhook-1.7.302 | v6.2.2 |
| longhorn-system | longhorn | 1 | 2024-03-27 07:10:17.736345393 +0000 UTC | deployed | longhorn-102.3.2+up1.5.4 | v1.5.4 |
| longhorn-system | longhorn-crd | 1 | 2024-03-27 07:10:13.265609724 +0000 UTC | deployed | longhorn-crd-102.3.2+up1.5.4 | v1.5.4 |
| opentelemetry-operator | otel | 2 | 2025-04-09 19:49:19.86190289 +0000 UTC | deployed | opentelemetry-operator-0.72.0 | 0.111.0 |
| pipelines | airflow | 1 | 2025-04-09 19:49:19.254061054 +0000 UTC | deployed | airflow-8.9.0 | 2.8.4 |
| pipelines | csx-deployment-data-n8n | 3 | 2025-04-09 19:49:05.476005103 +0000 UTC | deployed | csx-deployment-data-n8n-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-contextsuite | 21 | 2025-04-10 09:06:33.650347858 +0000 UTC | deployed | csx-deployment-apps-contextsuite-v0.0.0+git-dc48f3fbadf9 |  |
| solutions | csx-deployment-apps-ctxllm | 2 | 2025-04-09 19:48:57.040127992 +0000 UTC | deployed | csx-deployment-apps-ctxllm-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-cxs-mimir-api | 41 | 2025-04-10 21:22:23.604489184 +0000 UTC | deployed | csx-deployment-apps-cxs-mimir-api-v0.0.0+git-231246ea34f0 |  |
| solutions | csx-deployment-apps-cxs-mimir-chat | 9 | 2025-04-10 09:33:24.008110238 +0000 UTC | deployed | csx-deployment-apps-cxs-mimir-chat-v0.0.0+git-330aa7c4052b |  |
| solutions | csx-deployment-apps-cxs-services | 21 | 2025-04-09 19:48:52.076339715 +0000 UTC | deployed | csx-deployment-apps-cxs-services-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-formclient | 11 | 2025-04-10 15:39:05.026297272 +0000 UTC | deployed | csx-deployment-apps-formclient-v0.0.0+git-3d15a09f58a4 |  |
| solutions | csx-deployment-apps-gpt-api | 6 | 2025-04-09 19:48:52.84811952 +0000 UTC | deployed | csx-deployment-apps-gpt-api-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-gpt-chat | 2 | 2025-04-09 19:48:53.262746326 +0000 UTC | deployed | csx-deployment-apps-gpt-chat-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-mimir-api | 2 | 2025-04-09 19:48:57.707439147 +0000 UTC | deployed | csx-deployment-apps-mimir-api-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-mimir-chat | 4 | 2025-04-09 19:48:58.41653392 +0000 UTC | deployed | csx-deployment-apps-mimir-chat-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-service-runner | 20 | 2025-04-09 19:48:59.435468164 +0000 UTC | deployed | csx-deployment-apps-service-runner-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-translator-api | 3 | 2025-04-09 19:48:59.674022877 +0000 UTC | deployed | csx-deployment-apps-translator-api-v0.0.0+git-7d145304705f |  |
| solutions | csx-deployment-apps-translator-client | 3 | 2025-04-09 19:49:00.300722002 +0000 UTC | deployed | csx-deployment-apps-translator-client-v0.0.0+git-7d145304705f |  |
| tailscale | csx-deployment-authentication-tailscale | 3 | 2025-04-09 19:49:03.489035132 +0000 UTC | deployed | tailscale-operator-1.70.0 | v1.70.0 |


### Unclear stuff

#### Minio
We have definition for MinIO stored in:

- `data/c00dbmappings/overlays/production/minio.yaml`

and I can't find any pods, services, etc.  there is no `storage` namespace also.


#### Vault

The vault is installed from hashicorp helm chart and the only thing that is added is annotation for tailscale expose.

Configuration files are located at:

- `data/vault/`

There is one pvc _(10Gi)_ with storageclass `longhorn`. We should check if we need to migrate keys.


#### solr

solr is installed using solr apache helm chart. There is also `solr.prod.yml` which will create CRD `SolrCloud`. 


#### pipelines / nifi

Configuration files located at: `pipelines/nifi/` - there are resources provisioned in cluster


#### pipelines / airflow

Installed via helm chart with only one values file without an overlay. 

Configuration files located at: `pipelines/airflow/`

