# Data Layer Storage Analysis and Configuration

## Current Infrastructure Overview

### Hardware Configuration
- **Hosts**: c001db1, c001db2, c001db3 (3-node data layer cluster)
- **Physical storage per host**: 2x 8TB NVMe drives (shows as 7.3TiB each)
- **RAID Configuration**: RAID-0 (striping across both drives per host)
- **Usable capacity per host**: 14.6TB (OS partition)
- **Total cluster capacity**: ~44TB raw (3 x 14.6TB)
- **Current usage per host**: ~6% (786GB used, 13TB available)
- **Primary workload**: ClickHouse (critical production data)
- **Secondary workload**: MinIO (backup storage)

### RAID-0 Implications (Critical Risk Profile)
- **Performance**: High read/write performance due to striping across 2x 8TB drives
- **Risk**: **Zero fault tolerance per host** - failure of either drive results in complete node failure
- **Failure impact**: Single drive failure causes simultaneous loss of:
  - Operating system
  - ClickHouse data (critical production workload)  
  - MinIO data (backup storage)
- **Failure rate**: ~2x higher than single drive per host (6 drives total across cluster)
- **Cluster impact**: Node loss affects both ClickHouse and MinIO distributed operations

### Service Resilience Characteristics

#### ClickHouse (Primary Concern)
- **Data criticality**: Production analytical data 
- **Cluster configuration**: Unknown - requires assessment
- **Node failure impact**: Potentially catastrophic data loss per node
- **Recovery complexity**: High - requires ClickHouse cluster rebuild/restore

#### MinIO (Secondary Concern) 
- **Purpose**: Backup storage for pgBackRest and Longhorn
- **Data distribution**: Objects distributed across 3 nodes provides redundancy
- **Fault tolerance**: Can survive individual node failures (depending on erasure coding)
- **Node failure impact**: Reduced capacity but cluster continues operation
- **Recovery**: Automatic rebalancing when node returns


### Co-located Services (Critical Risk Factor)
- **ClickHouse**: Critical production workload sharing RAID-0 storage
- **MinIO**: Secondary backup service providing backup storage for pgBackRest and Longhorn
- **Operating System**: Root filesystem on same RAID-0 storage
- **Risk**: Single drive failure causes complete node failure affecting all services simultaneously
- **Total cluster exposure**: 6 physical drives across 3 nodes, any failure cascades to full node loss


## Strategic Architecture Options

### Option 1: RAID Reconfiguration  
- **Approach**: Convert RAID-0 to RAID-1 or RAID-5 on each node
- **Benefits**: Add fault tolerance, eliminate single drive failure risk
- **Challenges**: Requires complete rebuild, ~50% capacity reduction (RAID-1), extended downtime
- **Timeline**: Major infrastructure project requiring full data migration
- **Impact**: Addresses fundamental RAID-0 risk but reduces available capacity

### Option 2: External Storage Migration
- **Approach**: Migrate critical workloads to dedicated fault-tolerant storage
- **Benefits**: Eliminates RAID-0 risks, separates workloads, scalable
- **Challenges**: Additional hardware investment, network dependencies, migration complexity
- **Timeline**: Medium to long-term strategic initiative
- **Impact**: Best long-term solution but requires significant investment

### Option 3: Hybrid Approach
- **Approach**: Keep current setup for performance workloads, external storage for critical data
- **Benefits**: Maintains current performance, adds protection where needed
- **Challenges**: Operational complexity, data placement strategy required
- **Timeline**: Phased implementation possible
- **Impact**: Balanced approach addressing both performance and reliability needs

## Risk Assessment

### Current Risk Analysis

#### Critical Risks (High Impact, High Probability)
- **Single drive failure = complete node loss**: Any of 6 drives failing causes OS + ClickHouse + MinIO loss
- **ClickHouse data loss**: Critical production data vulnerable to single drive failure per node  
- **Cascading failure risk**: Node loss affects both primary (ClickHouse) and backup (MinIO) systems
- **No individual node recovery**: RAID-0 provides no fault tolerance

#### Secondary Risks (Medium Impact)
- **MinIO storage exhaustion**: Currently blocking backup operations (pgBackRest, Longhorn)
- **Backup system degradation**: Reduced redundancy for other systems
- **Cluster capacity**: Multiple node failures could overwhelm remaining capacity

### Post-MinIO Expansion Risk Profile
#### Risks Reduced
- **Backup operations restored**: Sufficient capacity for pgBackRest and Longhorn
- **MinIO cluster stability**: Better able to handle node loss/recovery cycles
- **Operational breathing room**: 10x capacity increase reduces storage pressure

#### Risks Unchanged (Critical)
- **ClickHouse exposure**: Still vulnerable to single drive failures per node
- **RAID-0 fundamental risk**: No improvement to node-level fault tolerance
- **Cascading failure risk**: Drive failure still causes complete node loss

## Backup Strategy Recommendations

### Current Backup Integration
- **pgBackRest**: Using MinIO as repo2 for PostgreSQL backups
- **Longhorn**: Using MinIO for volume snapshots
- **Status**: Both failing due to space constraints

### Required Improvements
1. **External backup destination**: Replicate critical data off RAID-0
2. **Cross-node replication**: MinIO distributed setup provides some resilience
3. **Regular backup validation**: Automated testing of restore procedures
4. **Monitoring**: Alert on storage usage thresholds

## Monitoring and Alerts

### Key Metrics to Monitor
- Loop device space utilization
- RAID-0 drive health (SMART data)
- MinIO cluster health
- Backup success rates
- Network connectivity between nodes

### Recommended Alerts
- Storage > 80% usage
- Drive SMART errors
- MinIO node failures
- Backup failures
- Network partition events

## Strategic Assessment

The c001dbx cluster represents a high-performance but high-risk storage architecture optimized for speed over resilience.
The fundamental RAID-0 design across all nodes creates single points of failure that affect critical production workloads.

### Key Considerations

**Current State**
- **Performance advantage**: RAID-0 provides excellent I/O performance for ClickHouse analytics workloads
- **Risk concentration**: 6 physical drives, any failure causes complete node loss including critical ClickHouse data
- **Service interdependence**: Operating system, ClickHouse, and backup systems share failure domains

**Strategic Priorities**
- **ClickHouse protection**: Critical production data requires fault-tolerant storage or comprehensive backup strategy
- **Risk diversification**: Current architecture concentrates too much risk in individual node storage
- **Operational resilience**: Need to reduce impact of inevitable drive failures

## Recommendations

### Immediate Risk Mitigation
1. **Assess ClickHouse cluster configuration** and replication status
2. **Implement comprehensive backup strategy** for ClickHouse data to external storage
3. **Document disaster recovery procedures** for complete node failures
4. **Establish proactive monitoring** for drive health (SMART data) across all 6 drives

### Long-term Architecture Evolution
1. **Evaluate RAID-1 migration** to eliminate single drive failure risk
2. **Consider storage architecture modernization** with separated compute and storage tiers
3. **Plan geographic distribution** of critical backups
4. **Design automated failover** and recovery procedures

### Operational Excellence
1. **Implement comprehensive monitoring** of cluster health and drive status
2. **Establish capacity planning** for sustainable growth
3. **Develop runbooks** for common failure scenarios
4. **Regular disaster recovery testing** to validate procedures

### Risk Monitoring
- **Drive health monitoring**: All 6 NVMe drives across cluster
- **Cluster health**: Both ClickHouse and MinIO availability
- **Backup success rates**: Critical for disaster recovery
- **Capacity trending**: Prevent future storage exhaustion