#!/bin/bash

SECRET_NAME="cxs-services-minio"
NAMESPACE="solutions"
BUCKET_NAME="rag-content-processing"
ENDPOINT="minio.data"

# Fail if envs are not set
if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
  echo "Error: MINIO_ACCESS_KEY and MINIO_SECRET_KEY must be set"
  exit 1
fi

# Check if the secret exists and fail with a message if so
if kubectl get secret $SECRET_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "Secret $SECRET_NAME already exists"
  exit 1
fi

kubectl create secret generic $SECRET_NAME \
  --namespace=$NAMESPACE \
  --from-literal=MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
  --from-literal=MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
  --from-literal=MINIO_BUCKET_NAME="$BUCKET_NAME" \
  --from-literal=MINIO_ENDPOINT="$ENDPOINT" \
  --from-literal=MINIO_SECURE="false"

echo "Secret created successfully"