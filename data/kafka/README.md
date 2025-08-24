# Kafka (dev/staging/production)

## Purpose
Kafka for the data layer. Dev uses a single-broker KRaft container; staging/prod use Strimzi Kafka clusters.

## Dev usage (Rancher Desktop)
```bash
cd data/kafka
./deploy-dev.sh
./test-connection.sh
# Expose locally if needed:
kubectl port-forward svc/kafka 9092:9092 -n data
```

## Remote usage
```bash
ENABLE_KAFKA=false
REMOTE_KAFKA_HOST=kafka.shared.dev.example.com
REMOTE_KAFKA_PORT=9092
```

## Environments
- dev: single broker, KRaft, IfNotPresent, small resources
- staging: Strimzi `Kafka` CR (3 brokers), medium resources
- production: Strimzi `Kafka` CR (3 brokers), PDB and NetworkPolicy, pinned version

## Fleet
`fleet.yaml` targets overlays by cluster label `env=dev|staging|production`.

See also:
- docs/migration-template.md
- docs/k8s-standards.md
- docs/solution-version-policy.md
