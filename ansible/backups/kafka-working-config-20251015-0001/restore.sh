#!/bin/bash
# Kafka Configuration Restore Script
# Created: 2025-10-15 00:01 UTC
# Purpose: Restore working Kafka configuration from backup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DATE="20251015-0001"

echo "=== Kafka Configuration Restore Script ==="
echo "Backup Date: $BACKUP_DATE"
echo "Backup Directory: $SCRIPT_DIR"
echo

# Stop Kafka services
echo "Stopping Kafka services on all nodes..."
ansible data_nodes -m systemd -a "name=kafka state=stopped"

# Restore configurations
echo "Restoring server.properties files..."
ansible c001db1 -m copy -a "src=$SCRIPT_DIR/c001db1/home/kafka/kafka/config/kraft/server.properties dest=/home/kafka/kafka/config/kraft/server.properties owner=kafka group=kafka mode=0644 backup=yes"
ansible c001db2 -m copy -a "src=$SCRIPT_DIR/c001db2/home/kafka/kafka/config/kraft/server.properties dest=/home/kafka/kafka/config/kraft/server.properties owner=kafka group=kafka mode=0644 backup=yes"
ansible c001db3 -m copy -a "src=$SCRIPT_DIR/c001db3/home/kafka/kafka/config/kraft/server.properties dest=/home/kafka/kafka/config/kraft/server.properties owner=kafka group=kafka mode=0644 backup=yes"

echo "Restoring log4j.properties files..."
ansible data_nodes -m copy -a "src=$SCRIPT_DIR/c001db1/home/kafka/kafka/config/log4j.properties dest=/home/kafka/kafka/config/log4j.properties owner=kafka group=kafka mode=0644 backup=yes"

echo "Restoring systemd service files..."
ansible data_nodes -m copy -a "src=$SCRIPT_DIR/c001db1/etc/systemd/system/kafka.service dest=/etc/systemd/system/kafka.service owner=root group=root mode=0644 backup=yes"

# Reload systemd and restart services
echo "Reloading systemd daemon..."
ansible data_nodes -m systemd -a "daemon_reload=yes"

echo "Starting Kafka services..."
ansible data_nodes -m systemd -a "name=kafka state=started" --forks=1

echo "Waiting for services to stabilize..."
sleep 10

# Verify cluster
echo "Verifying cluster health..."
ansible c001db1 -m shell -a "/home/kafka/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server c001db1:9092,c001db2:9092,c001db3:9092" || echo "Cluster verification failed - check logs"

echo "=== Restore Complete ==="