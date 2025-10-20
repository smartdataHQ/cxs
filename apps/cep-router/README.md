# CEP Router

## Purpose

The CEP Router acts as an intelligent front-end that routes API requests to the appropriate CEP Analyser instances based on API key mappings and region/cluster configurations. It maintains a registry of active analyser instances and handles load balancing and failover.

## Architecture

### Core Components
1. **Registration Service**: Manages CEP analyser instance registrations
2. **Routing Service**: Routes requests based on API key → region/cluster mappings  
3. **Heartbeat Monitor**: Tracks analyser instance health and availability
4. **Proxy Filter**: Forwards requests to the appropriate backend instance

### Key Features
- **Dynamic Registration**: CEP analyser instances register themselves automatically
- **Health Monitoring**: Continuous heartbeat monitoring with configurable grace periods
- **API Key Routing**: Maps API keys to specific region/cluster combinations
- **High Availability**: Can be scaled horizontally for redundancy
- **Diagnostics**: Built-in diagnostics and monitoring endpoints

## Deployment Structure

### Base Configuration
```
base/
├── deployment.yaml      # Scalable Deployment (2+ replicas for HA)
├── service.yaml        # ClusterIP service on port 8080
└── kustomization.yaml  # Common configuration
```

### Environment Overlays
```
overlays/
├── staging/            # Single replica, verbose diagnostics
└── production/         # Multiple replicas, optimized settings
```

## Configuration

### Environment Variables

#### Server Configuration
- `ROUTER_PORT`: HTTP server port (default: 8080)
- `SPRING_PROFILES_ACTIVE`: Spring profile (prod/staging)

#### Redis Configuration
- `REDIS_HOST`: Redis server for storing registrations and mappings
- `REDIS_PORT`: Redis port (default: 6379)
- `REDIS_PASSWORD`: Redis authentication (from secret)
- `REDIS_SSL`: Enable SSL for Redis connections

#### Router Behavior
- `ROUTER_HEARTBEAT_INTERVAL`: Expected heartbeat interval from analysers (seconds)
- `ROUTER_HEARTBEAT_GRACE_MULTIPLIER`: Grace period multiplier for missed heartbeats
- `ROUTER_DIAGNOSTICS_ENABLED`: Enable detailed diagnostics logging

#### Security
- `ROUTER_SECURITY_INTERNAL_TOKEN`: Token for secure analyser-router communication

## Integration with CEP Analyser

### Analyser Registration Process
1. CEP analyser starts up with router integration enabled
2. Analyser sends registration request to router with:
   - Region/cluster identity
   - Backend URL (service endpoint)
   - Heartbeat interval configuration
3. Router stores registration in Redis
4. Analyser sends periodic heartbeat messages
5. Router marks analysers as unhealthy if heartbeats stop

### Configuration in CEP Analyser
```yaml
# Required environment variables for analyser instances
- ROUTER_CLIENT_ENABLED="true"
- ROUTER_BASE_URL=http://cep-router.cep.svc.cluster.local:8080
- ROUTER_BACKEND_BASE_URL=http://{instance-name}-cep-analyser.cep.svc.cluster.local:9090
- ROUTER_CLIENT_REGION={region}
- ROUTER_CLIENT_CLUSTER={cluster}
- ROUTER_CLIENT_TOKEN={shared-secret}
```

## API Key Management

### Mapping API Keys to Instances
The router maintains mappings between API keys and region/cluster combinations:

```bash
# Example: Map API key to eu-west-1 production instance
POST /api/v1/mappings
{
  "apiKey": "customer-api-key-123",
  "region": "eu-west-1", 
  "cluster": "production"
}
```

### Request Routing Flow
1. Client sends request with API key in header (`x-api-key`)
2. Router looks up region/cluster for the API key
3. Router finds healthy analyser instance for that region/cluster
4. Router proxies request to the appropriate analyser
5. Router returns analyser response to client

## Endpoints

### Management Endpoints
- `GET /api/v1/registrations` - List active analyser registrations
- `GET /api/v1/mappings` - List API key mappings
- `POST /api/v1/mappings` - Create API key mapping
- `GET /api/v1/diagnostics` - Router diagnostics and health

### Health Endpoints
- `GET /actuator/health/liveness` - Liveness probe
- `GET /actuator/health/readiness` - Readiness probe
- `GET /actuator/metrics` - Prometheus metrics

### Analyser Registration (Internal)
- `POST /internal/register` - Analyser registration
- `POST /internal/heartbeat` - Analyser heartbeat

## Operational Considerations

### Scaling
- **Horizontal Scaling**: Multiple router replicas for high availability
- **Stateless Design**: All state stored in Redis for scalability
- **Load Balancing**: Kubernetes service handles load balancing between router replicas

### Monitoring
- **Registration Health**: Monitor active analyser registrations
- **Request Routing**: Track successful vs failed routing decisions  
- **Response Times**: Monitor proxy response times to detect analyser issues
- **Heartbeat Status**: Alert on analyser instances missing heartbeats

### Security
- **Internal Token**: Shared secret between router and analysers
- **API Key Validation**: Validates API keys before routing
- **Network Policies**: Restrict access to internal endpoints

## Troubleshooting

### Common Issues

1. **Analyser Not Receiving Requests**
   - Check if analyser is registered: `GET /api/v1/registrations`
   - Verify API key mapping: `GET /api/v1/mappings`
   - Check analyser heartbeat status

2. **Router Cannot Reach Analyser**
   - Verify service DNS resolution
   - Check network policies between namespaces
   - Validate analyser backend URL configuration

3. **Registration Failures**
   - Check internal token configuration
   - Verify Redis connectivity
   - Review router logs for authentication errors

### Diagnostic Commands
```bash
# Check router deployment
kubectl get deployment -n cep cep-router

# View router logs
kubectl logs -n cep deployment/cep-router

# Check active registrations
kubectl port-forward -n cep svc/cep-router 8080:8080
curl http://localhost:8080/api/v1/registrations

# Test API key routing
curl -H "x-api-key: test-key" http://localhost:8080/api/v1/diagnostics
```

## Secret Management

Required secrets in the `cep` namespace:
- `redis-auth`: Redis authentication
  - `password`: Redis password
- `cep-router-secrets`: Router-specific secrets
  - `internal-token`: Shared secret for analyser communication

## Dependencies

- **Redis**: For storing registrations and API key mappings
- **CEP Analyser Instances**: Backend services that register with router
- **Kubernetes DNS**: For service discovery and routing
