# Data Service Version Policy

## Overview

All development instances of data services in the CXS platform use the latest stable version of the underlying technology. This ensures that developers are working with up-to-date features, security patches, and performance improvements.

This policy aligns with our [First Principles and Directives](FIRST_PRINCIPLES.md), particularly:
- **Developer Experience First** - Ensures developers have access to the newest features
- **Simplicity Above All** - Uses straightforward versioning strategies
- **Progressive Enhancement** - Allows for easy upgrades from development to production

## Policy Details

### Development Environments
- **Use latest stable versions**: All dev instances use the latest stable version of each technology
- **Tag strategy**: Container images typically use the `latest` tag or are regularly updated to the newest stable release
- **Benefits**: 
  - Developers get access to the newest features
  - Reduces friction when upgrading to newer versions in production
  - Maintains consistency with upstream developments

### Staging/Production Environments
- **Use pinned versions**: Specific version tags are used for stability and predictability
- **Controlled upgrades**: Version upgrades are planned and tested before deployment
- **Security patches**: Critical security updates are applied as needed

## Implementation by Service

| Service | Dev Version | Production Version | Notes |
|---------|-------------|-------------------|-------|
| PostgreSQL | `postgres:latest` | Specific tag (e.g., `postgres:16.2`) | Uses official PostgreSQL images |
| ClickHouse | `clickhouse/clickhouse-server:latest` | Specific tag | Uses official ClickHouse images |
| Neo4j | `neo4j:latest` | Specific tag (e.g., `neo4j:5.10`) | Community edition |
| Kafka | `confluentinc/cp-kafka:latest` | Specific tag | Confluent Platform images |
| Solr | `solr:latest` | Specific tag (e.g., `solr:9.5.0`) | Official Apache Solr images |

## Rationale

1. **Developer Experience**: Ensures developers are working with the most current features and improvements
2. **Reduced Drift**: Minimizes the gap between development and production environments
3. **Security**: Provides the latest security patches in development environments
4. **Compatibility Testing**: Helps identify compatibility issues early in the development cycle

## Best Practices

1. **Regular Updates**: Development environments should be regularly updated to track the latest stable versions
2. **Version Documentation**: Always document the specific versions used in production environments
3. **Testing**: Thoroughly test applications when major version upgrades occur
4. **Monitoring**: Monitor for breaking changes in release notes when updating versions

## Exceptions

Certain services may require specific versions due to:
- Compatibility requirements with other services
- Known issues with the latest versions
- Feature requirements not available in newer versions

Any exceptions to this policy should be documented in the service-specific README files.