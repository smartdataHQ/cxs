#!/bin/bash
# Kafka Data Assessment Script for Longhorn Volume Recovery

echo "=== Kafka Data Recovery Assessment ==="
echo "Scanning Longhorn volumes for recoverable data..."

for broker in 0 1 2; do
    echo ""
    echo "=== BROKER $broker DATA ==="
    data_dir="/recovery/kafka-$broker"
    
    if [ -d "$data_dir" ]; then
        echo "📁 Data directory: $data_dir"
        echo "💾 Total size: $(du -sh $data_dir | cut -f1)"
        echo ""
        
        echo "📋 Topics found:"
        find $data_dir -maxdepth 1 -type d -name "*-[0-9]*" | while read topic_dir; do
            topic_name=$(basename "$topic_dir" | sed 's/-[0-9]*$//')
            partition=$(basename "$topic_dir" | sed 's/.*-//')
            log_files=$(find "$topic_dir" -name "*.log" | wc -l)
            total_size=$(du -sh "$topic_dir" | cut -f1)
            
            echo "  🗂️  $topic_name (partition $partition): $total_size ($log_files log files)"
            
            # Count messages in topic (first log file only for speed)
            first_log=$(find "$topic_dir" -name "*.log" | head -1)
            if [ -f "$first_log" ]; then
                msg_count=$(kafka-dump-log.sh --files "$first_log" 2>/dev/null | grep -c "^Dumping" || echo "N/A")
                echo "    📊 Sample messages in first log: $msg_count"
            fi
        done
    else
        echo "❌ Broker $broker data directory not found"
    fi
done

echo ""
echo "=== RECOVERY RECOMMENDATIONS ==="
echo "🔍 Prioritize these topics for recovery:"
echo "  1. audit.events-* (compliance data)"
echo "  2. content_processing_jobs-* (business workflows)"  
echo "  3. se2-* (domain-specific data)"
echo ""
echo "⚠️  Skip these internal topics:"
echo "  - __consumer_offsets-* (will rebuild)"
echo "  - _schemas-* (can be recreated)"
echo ""
echo "💡 Next steps:"
echo "  1. Run: bash /workspace/extract-topic-data.sh [topic-name]"
echo "  2. Transfer extracted data to external cluster"
echo "  3. Replay using kafka-console-producer.sh"