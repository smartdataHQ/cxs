#!/bin/bash

# CEP Analyser Instance Generator
# Usage: ./create-instance.sh <region> <cluster> [image-tag]

set -e

REGION="$1"
CLUSTER="$2"
IMAGE_TAG="${3:-latest}"

if [[ -z "$REGION" || -z "$CLUSTER" ]]; then
    echo "Usage: $0 <region> <cluster> [image-tag]"
    echo ""
    echo "Examples:"
    echo "  $0 eu-west-1 production v1.2.3"
    echo "  $0 us-east-1 staging develop"
    echo "  $0 ap-south-1 production latest"
    echo ""
    exit 1
fi

INSTANCE_NAME="${REGION}-${CLUSTER}"
INSTANCE_DIR="overlays/${INSTANCE_NAME}"

echo "Creating CEP Analyser instance: ${INSTANCE_NAME}"
echo "Region: ${REGION}"
echo "Cluster: ${CLUSTER}"
echo "Image Tag: ${IMAGE_TAG}"
echo ""

# Check if instance already exists
if [[ -d "$INSTANCE_DIR" ]]; then
    echo "❌ Instance directory already exists: $INSTANCE_DIR"
    echo "Delete it first or choose a different region/cluster combination"
    exit 1
fi

# Create instance directory
mkdir -p "$INSTANCE_DIR"

# Generate kustomization.yaml
cat > "$INSTANCE_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cep

resources:
  - ../../base

# Image tag for this instance
images:
  - name: quicklookup/cep-analyser
    newTag: ${IMAGE_TAG}

# Instance-specific configuration
configMapGenerator:
  - name: cep-analyser-config
    behavior: merge
    literals:
      # Instance Identity - CRITICAL for CEP customer bucketing
      - APP_REGION=${REGION}
      - APP_CLUSTER=${CLUSTER}
      - APP_INSTANCE=${INSTANCE_NAME}
      - APP_TOPIC_PREFIX=${REGION}-${CLUSTER:0:4}-
      
      # Router Integration - instance-specific backend URL
      - ROUTER_BACKEND_BASE_URL=http://${INSTANCE_NAME}-cep-analyser.cep.svc.cluster.local:9090
      - ROUTER_CLIENT_REGION=${REGION}
      - ROUTER_CLIENT_CLUSTER=${CLUSTER}

# Patch deployment for instance-specific settings
patchesStrategicMerge:
  - deployment-patch.yaml
  - service-patch.yaml

# Ensure unique resource names for this instance
namePrefix: ${INSTANCE_NAME}-

# Labels for this instance
commonLabels:
  instance: ${INSTANCE_NAME}
  region: ${REGION}
  cluster: ${CLUSTER}
EOF

# Generate deployment-patch.yaml
cat > "$INSTANCE_DIR/deployment-patch.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cep-analyser
spec:
  template:
    metadata:
      labels:
        instance: ${INSTANCE_NAME}
        region: ${REGION}
        cluster: ${CLUSTER}
    spec:
      containers:
      - name: cep-analyser
        # Instance-specific resource limits (adjust based on expected load)
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 2000m
            memory: 2Gi
EOF

# Generate service-patch.yaml
cat > "$INSTANCE_DIR/service-patch.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: cep-analyser
  labels:
    instance: ${INSTANCE_NAME}
    region: ${REGION}
    cluster: ${CLUSTER}
EOF

echo "✅ Created CEP Analyser instance: ${INSTANCE_NAME}"
echo ""
echo "📁 Files created:"
echo "  - $INSTANCE_DIR/kustomization.yaml"
echo "  - $INSTANCE_DIR/deployment-patch.yaml"
echo "  - $INSTANCE_DIR/service-patch.yaml"
echo ""
echo "📝 Next steps:"
echo "  1. Review and adjust resource limits in deployment-patch.yaml"
echo "  2. Commit and push changes to Git"
echo "  3. ArgoCD will automatically discover and deploy the new instance"
echo "  4. The instance will register with cep-router automatically"
echo ""
echo "🔍 Validate with:"
echo "  kubectl kustomize $INSTANCE_DIR"
echo ""
echo "🚀 The instance will be deployed as: ${INSTANCE_NAME}-cep-analyser"
echo "🔗 Router will route requests to: http://${INSTANCE_NAME}-cep-analyser.cep.svc.cluster.local:9090"