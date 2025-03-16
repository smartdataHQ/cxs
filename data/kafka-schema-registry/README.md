# Kafka Schema Registry

Manages the cp-kafka-registry setup in the cluster.

The chart is based from the [Confluent Schema Registry Helm Chart] with some
modifications, such as:

- customEnvBlock to allow for secret injection
- service annotation for tailscale

[Confluent Schema Registry Helm Chart]: https://github.com/confluentinc/cp-helm-charts/blob/master/charts/cp-schema-registry/README.md)

## Custom secret for connecting

Configuring the chart to use SASL_SSL with SCRAM-SHA-512 requires a secret
which can be generated using the following command:

```sh
./update-secret.sh
```
