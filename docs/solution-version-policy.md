# Solution Version Policy

## Overview

All development instances of solutions in the CXS platform use the latest stable version of their underlying technologies. This ensures that developers are working with up-to-date features, security patches, and performance improvements.

This policy aligns with our [First Principles and Directives](first-principles.md), particularly:
- **Developer Experience First**
- **Simplicity Above All**
- **Progressive Enhancement**

## Policy Details

### Development Environments
- **Use latest stable versions**: Dev instances use latest stable versions
- **Tag strategy**: Images may use `latest` (or frequent updates) in dev

### Staging/Production Environments
- **Use pinned versions**: Specific, immutable tags
- **Controlled upgrades**: Planned, tested, and documented
- **Security patches**: Applied as needed

## Implementation Examples

| Solution Type | Dev Tag (example) | Staging/Prod Tag (example) |
|---------------|--------------------|----------------------------|
| PostgreSQL | `postgres:latest` | `postgres:16.2-alpine` |
| ClickHouse | `clickhouse/clickhouse-server:latest` | `clickhouse/clickhouse-server:24.3` |
| Neo4j | `neo4j:latest` | `neo4j:5.10` |
| Kafka | `confluentinc/cp-kafka:latest` | `confluentinc/cp-kafka:7.6.0` |
| Solr | `solr:latest` | `solr:9.5.0` |
| Apps (Node) | `node:20` base image | Fixed app image by SHA/tag |

## Rationale

1. **Developer Experience**
2. **Reduced Drift**
3. **Security**
4. **Compatibility Testing**

## Best Practices

1. **Regular Updates** for dev
2. **Document Versions** used in prod/staging
3. **Test Thoroughly** across version bumps
4. **Monitor Release Notes** for breaking changes

## Automation directive: Always fetch latest stable releases (solution-agnostic)

Before selecting image tags for any solution, check the upstream for the latest GA/stable version and avoid RC/alpha/beta.

- Upstream release (GitHub API example):
  - `OWNER=myorg REPO=myrepo; curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest" | jq -r .tag_name`

- Container registry tags (Docker Hub API example):
  - `IMAGE_REPO=library/imagename; curl -s "https://registry.hub.docker.com/v2/repositories/${IMAGE_REPO}/tags/?page_size=100" | jq -r '.results[].name' | grep -E '^[0-9]+' | grep -viE 'rc|alpha|beta' | sort -V | tail -1`

- Apply per policy:
  - Dev overlays: set images to latest stable (or `:latest`) via Kustomize `images` override; do not set tags in base.
  - Staging/Production overlays: pin immutable tags in overlays; base remains tag-less.

Document pinned versions in the solution README when updating staging/production.

## Exceptions

Certain solutions may require specific versions due to:
- Inter-solution compatibility
- Known issues with latest versions
- Required features in specific versions

Document exceptions in the solution’s README.
