# rancher-monitoring (metrics pipeline)

Prometheus + prometheus-operator + kube-state-metrics + node-exporter for the
production cluster, deployed from chart `rancher-monitoring`
`108.0.1+up77.9.1-rancher.10` (charts.rancher.io) — the same chart + version
the fraios dev cluster runs.

## Why it exists

Grafana (`monitoring/grafana`, grafana.contextsuite.com) is the alerting
surface. Its default Prometheus datasource points at
`http://rancher-monitoring-prometheus.cattle-monitoring-system:9090`, and the
provisioned alert rules (`grafana-postgresql-backup-alerts`,
`grafana-longhorn-alerts`) query `kube_job_status_*` and Longhorn metrics.
Before this app existed, no Prometheus ran on the cluster at all — every rule
on that datasource fired `DatasourceError` instead of evaluating, and
`monitoring-service-monitors` could not sync (no `cattle-monitoring-system`
namespace).

## Shape

- **Enabled**: prometheus-operator, Prometheus (15d / 45GB retention, 50Gi
  Longhorn PVC, 1Gi request / 3Gi limit — the cluster is memory-tight),
  kube-state-metrics, node-exporter, kubelet/cadvisor + coredns scraping.
- **Disabled**: bundled Grafana and Alertmanager (Grafana in the `grafana` ns
  owns dashboards + alerting), prometheus-adapter (rke2-metrics-server already
  serves the metrics API), control-plane component scraping
  (apiserver/etcd/scheduler/controller-manager/kube-proxy).
- Prometheus prefers scheduling away from `famous-stork` (highest actual
  memory use of the three nodes).
- `serviceMonitor/podMonitor/rule/probeSelectorNilUsesHelmValues: false` — the
  operator picks up ServiceMonitors/PrometheusRules from every namespace,
  including everything `monitoring/service-monitors` ships.

## CRDs

`base/kustomization.yaml` references the 10 prometheus-operator v0.85.0 CRDs
as kustomize remote resources — the exact immutable upstream tag URLs that
chart `rancher-monitoring-crd 108.0.1+up77.9.1-rancher.10` vendors from
(verified byte-identical to the chart's payload). The crd-chart itself wraps
them in a bz2 ConfigMap + helm-hook Job, which ArgoCD orders wrongly
(PostSync — after the CRs that need them); plain CRDs sync first. They carry
`argocd.argoproj.io/sync-options: ServerSideApply=true` (added by a kustomize
patch) because they exceed the client-side-apply annotation limit.

When bumping the chart version, point the URLs at the operator version the new
chart pins (visible in the rendered operator Deployment's image tag).

## Chart quirks handled in the overlay

- The chart's `pre-upgrade` migration Job (`rancher-monitoring-upgrade`) is
  **deleted via kustomize patch**: ArgoCD maps `pre-upgrade` to PreSync, so it
  would delete the node-exporter DaemonSet and kube-state-metrics Deployment
  on every sync. It only exists to migrate labels across chart majors under
  `helm upgrade`.
- `rke2IngressNginx.networkPolicy` / `loggingMonitors.*` /
  `rancherBackupMonitoring.dashboards` set to avoid the chart's nil-pointer
  template bugs (same keys the fraios dev values carry).
- The windows-exporter DaemonSet renders regardless of values but its
  `kubernetes.io/os: windows` nodeSelector schedules zero pods here.

## Verifying after a sync

```bash
kubectl -n cattle-monitoring-system get pods
# operator, prometheus-rancher-monitoring-prometheus-0, kube-state-metrics, node-exporter x3
kubectl -n cattle-monitoring-system exec sts/prometheus-rancher-monitoring-prometheus -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=kube_job_status_succeeded' | head -c 300
```

Then in Grafana: the `pg-backup-repo1-stale` / `pg-backup-repo2-stale` rules
should evaluate (Normal, not DatasourceError) within one 5m interval.
