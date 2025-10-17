#!/bin/bash
set -euo pipefail

# Test script for dual-port Kafka authentication
# Tests both PLAINTEXT (9092) and SASL_PLAINTEXT (9093) ports

KAFKA_NODES="${KAFKA_NODES:-c001db1,c001db2,c001db3}"
KAFKA_HOME="${KAFKA_HOME:-/home/kafka/kafka}"

# SASL credentials (matching K8s cluster)
SASL_USER="${KAFKA_SASL_USER:-user1}"
SASL_PASSWORD="${KAFKA_SASL_PASSWORD:-qCD9zc70ie}"

echo "=== Kafka Dual-Port Authentication Test ==="
echo "Testing nodes: $KAFKA_NODES"
echo "Timestamp: $(date)"
echo ""

# Test each node
for node in ${KAFKA_NODES//,/ }; do
    echo "--- Testing $node ---"
    
    # Test PLAINTEXT port (9092) - should work without credentials
    echo "Testing PLAINTEXT port 9092 (no auth required):"
    if timeout 10 "$KAFKA_HOME/bin/kafka-topics.sh" \
        --bootstrap-server "$node:9092" \
        --list >/dev/null 2>&1; then
        echo "✅ Port 9092 PLAINTEXT: SUCCESS"
    else
        echo "❌ Port 9092 PLAINTEXT: FAILED"
    fi
    
    # Test SASL port (9093) - requires credentials
    echo "Testing SASL_PLAINTEXT port 9093 (auth required):"
    
    # Create temporary client properties for SASL
    TEMP_PROPS=$(mktemp)
    cat > "$TEMP_PROPS" <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \\
  username="$SASL_USER" \\
  password="$SASL_PASSWORD";
EOF
    
    if timeout 10 "$KAFKA_HOME/bin/kafka-topics.sh" \
        --bootstrap-server "$node:9093" \
        --command-config "$TEMP_PROPS" \
        --list >/dev/null 2>&1; then
        echo "✅ Port 9093 SASL_PLAINTEXT: SUCCESS"
    else
        echo "❌ Port 9093 SASL_PLAINTEXT: FAILED"
    fi
    
    # Test SASL port without credentials (should fail)
    echo "Testing port 9093 without credentials (should fail):"
    if timeout 10 "$KAFKA_HOME/bin/kafka-topics.sh" \
        --bootstrap-server "$node:9093" \
        --list >/dev/null 2>&1; then
        echo "❌ Port 9093 without auth: UNEXPECTED SUCCESS (security issue!)"
    else
        echo "✅ Port 9093 without auth: CORRECTLY FAILED"
    fi
    
    # Cleanup
    rm -f "$TEMP_PROPS"
    echo ""
done

echo "=== Port Status Check ==="
for node in ${KAFKA_NODES//,/ }; do
    echo "Port status on $node:"
    ssh "$node" "ss -tlnp | grep -E ':(9092|9093)' | grep java || echo 'No Kafka ports found'"
    echo ""
done

echo "=== Test Complete ==="