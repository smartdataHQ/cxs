#!/usr/bin/env bash

set -euo pipefail

password="$(kubectl get secret kafka-user-passwords --namespace data -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)";


cat <<EOF | kubectl apply -f -
apiVersion: v1
stringData:
  SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG: |
    org.apache.kafka.common.security.scram.ScramLoginModule required username="user1" password="$password";
kind: Secret
metadata:
  name: kafka-schema-registry
  namespace: data
type: Opaque
EOF
