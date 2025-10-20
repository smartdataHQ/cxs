# CEP Analyser

## Purpose

The CEP (Complex Event Processing) Analyser is a backend service that processes event streams using Esper CEP engine. Due to CEP limitations, complex patterns cannot be detected if multiple instances analyze fragments of the event stream. Therefore, we use a **customer bucketing strategy** where each CEP analyser instance handles specific customers based on region/cluster configuration.

## Architecture

### Key Constraints
- **Single Instance per Region/Cluster**: Each deployment runs exactly 1 replica due to CEP processing requirements
- **Customer Bucketing**: Customers are assigned to specific instances based on region/cluster settings
- **Non-Scalable by Design**: Horizontal scaling would break CEP pattern detection
- **Instance Isolation**: Each instance has unique region/cluster identity

### Configuration Pattern

Each CEP analyser instance is configured with three critical identity parameters:
- `APP_REGION`: Geographic or logical region (e.g., `eu-west-1`, `us-east-1`)
- `APP_CLUSTER`: Environment cluster (e.g., `production`, `staging`, `development`)  
- `APP_INSTANCE`: Unique instance identifier (typically `{region}-{cluster}`)

## Deployment Structure

### Base Configuration
```
base/
├── deployment.yaml      # Simple Deployment (replicas: 1, strategy: Recreate)
├── service.yaml        # ClusterIP service
└── kustomization.yaml  # Common configuration
```

### Instance-Based Overlays
```
overlays/
├── {region}-{cluster}/
│   ├── kustomization.yaml     # Instance-specific config
│   ├── deployment-patch.yaml  # Resource limits, labels
│   └── service-patch.yaml     # Service labels
```

### Active Instance
- `eu-north-1-production-default/`: Nordic production customers (Iceland deployment)

## Adding New Instances

To deploy a new CEP analyser instance for a different region/cluster:

1. **Create Instance Directory**:
   ```bash
   mkdir -p overlays/{region}-{cluster}
   ```

2. **Copy Template Files**:
   ```bash
   # Use existing instance as template
   cp -r overlays/eu-north-1-production-default/* overlays/{region}-{cluster}/
   ```

3. **Update Configuration** in `kustomization.yaml`:
   ```yaml
   # Instance Identity - CRITICAL for CEP customer bucketing
   - APP_REGION={your-region}
   - APP_CLUSTER={your-cluster}  
   - APP_INSTANCE={region}-{cluster}
   - APP_TOPIC_PREFIX={region}-{cluster-short}-
   
   # Unique resource names
   namePrefix: {region}-{cluster}-
   
   # Instance labels
   commonLabels:
     instance: {region}-{cluster}
     region: {your-region}
     cluster: {your-cluster}
   ```

4. **Update Image Tag**:
   ```yaml
   images:
     - name: quicklookup/cep-analyser
       newTag: {appropriate-tag}
   ```

5. **Adjust Resources** in `deployment-patch.yaml` based on expected load

6. **Deploy via ArgoCD**: ArgoCD will automatically discover the new overlay

## Configuration Details

### Environment Variables

#### Core Application Settings
- `APP_REGION`: Instance region identifier
- `APP_CLUSTER`: Instance cluster identifier  
- `APP_INSTANCE`: Unique instance name
- `APP_TOPIC_PREFIX`: Kafka topic prefix for this instance

#### Database Configuration
- `DB_HOST`: PostgreSQL host (shared across instances)
- `DB_NAME`: Database name (`cep_analyser_db`)
- `DB_USERNAME`: Database user (`cep`)
- `DB_PASSWORD`: From secret `cxs-pg-pguser-cep`

#### Kafka Configuration  
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka cluster endpoints
- `SCHEMA_REGISTRY_URL`: Avro schema registry
- Topic prefixing ensures instance isolation

#### Router Integration (Optional)
- `ROUTER_CLIENT_ENABLED`: Enable/disable router registration
- `ROUTER_CLIENT_REGION`: Must match `APP_REGION`
- `ROUTER_CLIENT_CLUSTER`: Must match `APP_CLUSTER`

### Secret Management

Each instance uses these secrets:
- `cxs-pg-pguser-cep`: Database credentials
- `redis-auth`: Redis authentication
- `cep-analyser-secrets`: Instance-specific secrets
  - `vault-token`: Vault access token
  - `jwt-secret`: JWT signing secret
  - `router-token`: Router API token (if enabled)
  - `rsa-private-key`: CEP signing key
  - `rsa-public-key`: CEP verification key

## Operational Considerations

### Resource Planning
- **CPU**: 200m-500m request, 1-4 CPU limit depending on load
- **Memory**: 512Mi-1Gi request, 2-4Gi limit for JVM heap
- **Storage**: Only ephemeral storage needed

### Monitoring
- **Health Checks**: Spring Boot Actuator endpoints
  - Liveness: `/actuator/health/liveness`
  - Readiness: `/actuator/health/readiness`
- **Metrics**: Available at `/actuator/metrics`

### Customer Assignment Strategy
Customers must be consistently routed to the same CEP instance to maintain:
- Event stream continuity
- Pattern state consistency  
- Complex event correlation

### Scaling Considerations
- **Vertical Scaling**: Increase CPU/memory for higher throughput
- **Instance Addition**: Deploy new region/cluster instances for geographic distribution
- **Never Horizontal Scale**: Multiple replicas of same instance will break CEP

## Migration from Old Deployment

The previous deployment used StatefulSet with complex configuration. Key changes:
- ✅ **Simplified**: Deployment instead of StatefulSet
- ✅ **Instance-Based**: Clear region/cluster separation
- ✅ **Extensible**: Easy to add new instances
- ✅ **ArgoCD Ready**: Automatic discovery of new overlays
- ✅ **Resource Optimized**: Appropriate limits per instance

## Troubleshooting

### Common Issues
1. **CEP Pattern Detection Failing**: Check that only 1 replica is running
2. **Customer Events Missing**: Verify topic prefix and Kafka routing
3. **Instance Identity Conflicts**: Ensure unique APP_REGION/APP_CLUSTER combinations
4. **Database Connection Issues**: Verify PostgreSQL user `cep` has proper permissions

### Validation Commands
```bash
# Check deployment status
kubectl get deployment -n cep -l app=cep-analyser

# Verify configuration
kubectl get configmap -n cep -l app=cep-analyser -o yaml

# Check instance identity
kubectl logs -n cep deployment/{instance-name}-cep-analyser | grep "APP_REGION\|APP_CLUSTER"
```
