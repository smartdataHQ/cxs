#!/bin/bash
# Kafka Data Recovery Script - Direct Node Access
# Run this script on Kubernetes nodes with Longhorn volumes

set -e

LONGHORN_DATA_DIR="/var/lib/longhorn"
RECOVERY_DIR="/tmp/kafka-recovery"
EXTERNAL_BROKERS="c001db1:9092,c001db2:9092,c001db3:9092"

# Kafka volume IDs (PVC names)
KAFKA_VOLUMES=(
    "pvc-5a06f2f5-9468-4270-92c3-179ee37ce272"  # kafka-broker-0
    "pvc-506850a8-e124-46f8-bfea-2ce2a5deaaf3"  # kafka-broker-1
    "pvc-b7693b29-bb92-4867-b375-8b54e48b8f18"  # kafka-broker-2
)

function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

function find_volume_data() {
    local volume_id=$1
    local volume_path
    
    # Search for Longhorn volume data directory
    for base_dir in "$LONGHORN_DATA_DIR/volumes" "/var/lib/rancher/longhorn/volumes"; do
        if [ -d "$base_dir/$volume_id" ]; then
            volume_path="$base_dir/$volume_id"
            break
        fi
    done
    
    if [ -z "$volume_path" ]; then
        log "❌ Volume $volume_id not found on this node"
        return 1
    fi
    
    # Find actual data directory (usually in a replica subfolder)
    local data_dir
    data_dir=$(find "$volume_path" -type d -name "*replica*" | head -1)
    
    if [ -z "$data_dir" ]; then
        log "❌ No replica data found for volume $volume_id"
        return 1
    fi
    
    echo "$data_dir"
    return 0
}

function assess_kafka_data() {
    log "🔍 Assessing Kafka data on node $(hostname)"
    
    mkdir -p "$RECOVERY_DIR"
    
    for i in "${!KAFKA_VOLUMES[@]}"; do
        local volume_id="${KAFKA_VOLUMES[$i]}"
        local broker_id="$i"
        
        log "📋 Checking broker-$broker_id volume: $volume_id"
        
        local data_dir
        if data_dir=$(find_volume_data "$volume_id"); then
            log "✅ Found data at: $data_dir"
            
            # List topics and sizes
            log "📁 Topics found:"
            find "$data_dir" -maxdepth 1 -type d -name "*-[0-9]*" | while read topic_dir; do
                local topic_name=$(basename "$topic_dir" | sed 's/-[0-9]*$//')
                local partition=$(basename "$topic_dir" | sed 's/.*-//')
                local size=$(du -sh "$topic_dir" 2>/dev/null | cut -f1 || echo "N/A")
                local log_count=$(find "$topic_dir" -name "*.log" | wc -l)
                
                echo "  🗂️  $topic_name-$partition: $size ($log_count log files)"
            done
        else
            log "⚠️  Volume $volume_id not on this node"
        fi
    done
}

function extract_topic() {
    local topic_name="$1"
    local output_file="$RECOVERY_DIR/${topic_name}-$(hostname)-$(date +%s).jsonl"
    
    if [ -z "$topic_name" ]; then
        log "❌ Usage: extract_topic <topic-name>"
        return 1
    fi
    
    log "📤 Extracting topic: $topic_name"
    
    for i in "${!KAFKA_VOLUMES[@]}"; do
        local volume_id="${KAFKA_VOLUMES[$i]}"
        local broker_id="$i"
        
        local data_dir
        if data_dir=$(find_volume_data "$volume_id"); then
            # Find all partitions for this topic
            find "$data_dir" -maxdepth 1 -type d -name "${topic_name}-*" | while read partition_dir; do
                local partition=$(basename "$partition_dir" | sed "s/${topic_name}-//")
                
                log "📄 Extracting broker-$broker_id, partition $partition"
                
                # Process all log files for this partition
                find "$partition_dir" -name "*.log" | sort | while read log_file; do
                    # Use kafka-dump-log equivalent or hex dump approach
                    log "  Processing: $(basename $log_file)"
                    
                    # Simple approach: extract binary data and convert what we can
                    # Note: This is simplified - full implementation needs proper Kafka log parsing
                    strings "$log_file" | grep -v "^$" | while read line; do
                        if [[ ${#line} -gt 10 ]]; then  # Only lines with substantial content
                            echo "{\"broker\":$broker_id,\"partition\":$partition,\"data\":\"$(echo "$line" | sed 's/"/\\"/g')\"}" >> "$output_file"
                        fi
                    done
                done
            done
        fi
    done
    
    if [ -f "$output_file" ]; then
        local count=$(wc -l < "$output_file")
        local size=$(du -sh "$output_file" | cut -f1)
        log "✅ Extracted $count records ($size) to: $output_file"
        echo "$output_file"
    else
        log "❌ No data extracted for topic: $topic_name"
        return 1
    fi
}

function create_replay_script() {
    local extracted_file="$1"
    local topic_name="$2"
    local replay_script="$RECOVERY_DIR/replay-$(basename $extracted_file .jsonl).sh"
    
    cat > "$replay_script" << EOF
#!/bin/bash
# Replay extracted Kafka data to external cluster

echo "Replaying data from: $extracted_file"
echo "Target cluster: $EXTERNAL_BROKERS"
echo "Topic: $topic_name"

# Create topic on external cluster (if needed)
kafka-topics.sh \\
    --bootstrap-server $EXTERNAL_BROKERS \\
    --create \\
    --topic "$topic_name" \\
    --partitions 3 \\
    --replication-factor 3 \\
    --if-not-exists

# Replay data
jq -r '.data' "$extracted_file" | \\
kafka-console-producer.sh \\
    --bootstrap-server $EXTERNAL_BROKERS \\
    --topic "$topic_name"

echo "✅ Replay complete"
EOF

    chmod +x "$replay_script"
    log "📝 Created replay script: $replay_script"
    echo "$replay_script"
}

# Main execution
case "${1:-assess}" in
    "assess")
        assess_kafka_data
        ;;
    "extract")
        if [ -z "$2" ]; then
            log "❌ Usage: $0 extract <topic-name>"
            exit 1
        fi
        extracted_file=$(extract_topic "$2")
        if [ $? -eq 0 ]; then
            create_replay_script "$extracted_file" "$2"
        fi
        ;;
    "help")
        echo "Kafka Node Recovery Tool"
        echo ""
        echo "Commands:"
        echo "  assess          - Scan node for Kafka volumes and data"
        echo "  extract <topic> - Extract specific topic data"
        echo "  help           - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 assess"
        echo "  $0 extract audit.events"
        echo "  $0 extract content_processing_jobs"
        ;;
    *)
        log "❌ Unknown command: $1"
        log "Run '$0 help' for usage information"
        exit 1
        ;;
esac