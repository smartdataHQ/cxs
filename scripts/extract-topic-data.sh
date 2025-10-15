#!/bin/bash
# Extract topic data from Kafka log segments for external cluster replay

if [ $# -ne 1 ]; then
    echo "Usage: $0 <topic-name>"
    echo "Example: $0 audit.events"
    exit 1
fi

TOPIC_NAME="$1"
OUTPUT_DIR="/workspace/extracted"
mkdir -p "$OUTPUT_DIR"

echo "=== Extracting data for topic: $TOPIC_NAME ==="

# Find all partitions for this topic across all brokers
for broker in 0 1 2; do
    data_dir="/recovery/kafka-$broker"
    
    # Find topic partitions in this broker
    find "$data_dir" -maxdepth 1 -type d -name "${TOPIC_NAME}-*" | while read partition_dir; do
        partition=$(basename "$partition_dir" | sed "s/${TOPIC_NAME}-//")
        echo "📁 Processing broker $broker, partition $partition"
        
        output_file="$OUTPUT_DIR/${TOPIC_NAME}-partition-${partition}-broker-${broker}.json"
        
        # Extract all log files for this partition
        find "$partition_dir" -name "*.log" | sort | while read log_file; do
            echo "  📄 Extracting: $(basename $log_file)"
            
            # Dump log file to JSON format (key|value format)
            kafka-dump-log.sh \
                --files "$log_file" \
                --print-data-log \
                --key-decoder-class kafka.serialization.StringDecoder \
                --value-decoder-class kafka.serialization.StringDecoder 2>/dev/null | \
                grep -E "^partition:|^offset:|^key:|^value:" | \
                paste - - - - | \
                sed 's/partition:\([0-9]*\)\toffset:\([0-9]*\)\tkey:\(.*\)\tvalue:\(.*\)/{"partition":\1,"offset":\2,"key":"\3","value":"\4"}/' \
                >> "$output_file"
        done
        
        if [ -f "$output_file" ]; then
            msg_count=$(wc -l < "$output_file")
            file_size=$(du -sh "$output_file" | cut -f1)
            echo "  ✅ Extracted $msg_count messages ($file_size) to: $output_file"
        fi
    done
done

echo ""
echo "=== Extraction Summary ==="
ls -lh "$OUTPUT_DIR"/${TOPIC_NAME}*.json 2>/dev/null | while read line; do
    echo "📋 $line"
done

echo ""
echo "=== Replay Commands ==="
echo "To replay this data to external cluster:"
for file in "$OUTPUT_DIR"/${TOPIC_NAME}*.json; do
    if [ -f "$file" ]; then
        echo "  jq -r '.key + \"|\" + .value' '$file' | \\"
        echo "    kafka-console-producer.sh \\"
        echo "      --bootstrap-server c001db1:9092,c001db2:9092,c001db3:9092 \\"
        echo "      --topic '$TOPIC_NAME' \\"
        echo "      --property parse.key=true \\"
        echo "      --property key.separator='|'"
        echo ""
    fi
done