# Kafka Schema Registry (Confluent Inc. Helm Chart)

## Purpose
Provides a schema registry for Kafka. It allows for managing and validating schemas for messages produced to and consumed from Kafka topics, ensuring data consistency and compatibility. This setup is based on the Confluent Schema Registry Helm Chart with some modifications.

## Configuration
- Configuration is primarily managed via the Helm chart located in the `cp-schema-registry/` subdirectory and its associated `values.yaml` file at the root of `data/kafka-schema-registry/`.
- The `values.yaml` file likely overrides default chart values to customize the Schema Registry deployment.
- **Customizations mentioned in the original README:**
    - `customEnvBlock` to allow for secret injection.
    - Service annotation for Tailscale.
- **Secrets:**
    - Secrets (e.g., for SASL_SSL with SCRAM-SHA-512 connection to Kafka) are managed in Rancher and injected at deployment time.
    - The `update-secret.sh` script is provided to help generate or update a secret needed for SASL communication. Refer to the main project `README.md` for general guidance on secret management.

## Deployment
- The Kafka Schema Registry is deployed via Fleet, as specified in `fleet.yaml`.
- Fleet uses the Helm chart from the `cp-schema-registry/` directory and the `values.yaml` file to deploy and manage the Schema Registry.

## Backup and Restore
[Details on backup and restore procedures for the Kafka Schema Registry need to be added. This typically involves backing up the underlying Kafka topic (`_schemas`) where the schemas are stored.]

## Key Files
- `fleet.yaml`: Fleet configuration for deployment.
- `values.yaml`: Helm values file for customizing the Schema Registry chart.
- `cp-schema-registry/`: Directory containing the Helm chart for Confluent Schema Registry.
    - `cp-schema-registry/Chart.yaml`: Defines the chart information.
    - `cp-schema-registry/values.yaml`: Default values for the chart (overridden by the parent `values.yaml`).
    - `cp-schema-registry/templates/`: Contains the Kubernetes manifest templates for the chart.
- `update-secret.sh`: Script to assist in generating a secret for SASL communication.
- `README.md`: This file.

## Further Reading
- [Confluent Schema Registry Helm Chart Documentation](https://github.com/confluentinc/cp-helm-charts/blob/master/charts/cp-schema-registry/README.md) (Note: This link points to the original base chart, not necessarily the customized version in this repository).
