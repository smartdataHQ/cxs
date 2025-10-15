# Kafka Data Recovery Incident - October 15, 2025

## Overview

During the external Kafka cluster migration, we discovered 385 days of valuable business data trapped in non-functional Kubernetes Longhorn volumes. This incident documents the data recovery process and automation tools.

## Files in this Directory

- **`KAFKA_RECOVERY_FACTS.yaml`** - Complete recovery facts, volume mappings, and automation commands
- **`kafka-node-recovery.sh`** - Main recovery script for direct node access
- **`assess-kafka-data.sh`** - Data assessment and topic discovery tool  
- **`extract-topic-data.sh`** - Topic-specific data extraction utility
- **`kafka-data-recovery-pod.yaml`** - Kubernetes pod manifest (backup approach)

## Problem Statement

- **K8s Kafka cluster**: Non-functional, volumes won't mount to pods
- **Data trapped**: 3x 80GB Longhorn volumes with 385 days of business data
- **Critical topics**: audit.events, content_processing_jobs, domain-specific data
- **Recovery method**: Direct node filesystem access required

## Recovery Strategy

1. **Volume Mapping** - Locate Longhorn volumes on cluster nodes
2. **Data Assessment** - Inventory topics and sizes per node  
3. **Critical Extraction** - Extract business-critical topics first
4. **Data Transfer** - Move extracted data to external cluster
5. **Verification** - Ensure data integrity and completeness

## Usage

```bash
# 1. Map volumes to nodes
for vol in pvc-5a06f2f5-9468-4270-92c3-179ee37ce272 pvc-506850a8-e124-46f8-bfea-2ce2a5deaaf3 pvc-b7693b29-bb92-4867-b375-8b54e48b8f18; do
  echo -n "$vol -> "
  kubectl get -n longhorn-system volume.longhorn.io $vol -o jsonpath='{.status.currentNodeID}'
  echo
done

# 2. Copy recovery script to nodes
kubectl cp kafka-node-recovery.sh {node-name}:/tmp/kafka-node-recovery.sh

# 3. Run assessment
kubectl exec -it {node-name} -- /tmp/kafka-node-recovery.sh assess

# 4. Extract critical topics
kubectl exec -it {node-name} -- /tmp/kafka-node-recovery.sh extract audit.events
kubectl exec -it {node-name} -- /tmp/kafka-node-recovery.sh extract content_processing_jobs

# 5. Copy data back
kubectl cp {node-name}:/tmp/kafka-recovery ./kafka-recovery-data
```

## Recovery Timeline

- **Volume mapping**: 30 minutes
- **Data assessment**: 1 hour  
- **Critical extraction**: 2-4 hours
- **Data replay**: 1-2 hours
- **Verification**: 1 hour
- **Total estimated**: 6-9 hours

## Status

- [x] Recovery strategy documented
- [x] Automation scripts created
- [x] Volume locations identified (partial)
- [ ] Data extraction in progress
- [ ] External cluster replay pending
- [ ] End-to-end verification pending

## Next Steps

1. Complete volume-to-node mapping
2. Execute data assessment on all nodes
3. Extract and replay critical business data
4. Update applications to use external cluster
5. Verify complete data recovery