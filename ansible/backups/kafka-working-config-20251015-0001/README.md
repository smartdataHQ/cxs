# Kafka Working Configuration Backup

**Created:** 2025-10-15 00:01 UTC  
**Status:** Verified Working Configuration  
**Cluster State:** All 3 brokers healthy and communicating

## Contents

This backup contains the working Kafka configuration that was restored after the cluster recovery operation:

### Configuration Files (per node)
- `server.properties` - KRaft mode configuration with correct node IDs and advertised listeners
- `log4j.properties` - Logging configuration
- `kafka.service` - systemd service definition

### Node Configuration Summary

| Node | ID | Advertised Listener | Role |
|------|----|--------------------|------|
| c001db1 | 1 | c001db1:9092 | broker,controller |
| c001db2 | 2 | c001db2:9092 | broker,controller |
| c001db3 | 3 | c001db3:9092 | broker,controller |

### Key Configuration Settings

- **Mode:** KRaft (no ZooKeeper)
- **Protocol:** PLAINTEXT (no authentication at time of backup)
- **Controller Quorum:** 1@c001db1:9093,2@c001db2:9093,3@c001db3:9093
- **Log Directory:** `/home/kafka/kafka/data`
- **Partitions:** 6 default per topic
- **Replication Factor:** 2 for internal topics

## Restoration

To restore this configuration:

```bash
cd ansible
./backups/kafka-working-config-20251015-0001/restore.sh
```

The restore script will:
1. Stop all Kafka services
2. Restore configuration files with backups
3. Reload systemd daemon
4. Start services sequentially
5. Verify cluster connectivity

## Verification Commands

After restoration, verify with:

```bash
# Check service status
ansible data_nodes -m shell -a "systemctl is-active kafka"

# Test connectivity
ansible c001db1 -m shell -a "/home/kafka/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server c001db1:9092,c001db2:9092,c001db3:9092"

# List topics
ansible c001db1 -m shell -a "/home/kafka/kafka/bin/kafka-topics.sh --bootstrap-server c001db1:9092,c001db2:9092,c001db3:9092 --list"
```

## Notes

- This backup was created after successfully restoring the cluster from a failed authentication attempt
- The configuration uses c001db3's working settings as the baseline
- All nodes have identical settings except for `node.id` and `advertised.listeners`
- Services were verified healthy and all brokers accessible before backup creation