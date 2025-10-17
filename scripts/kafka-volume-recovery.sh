#!/bin/bash
set -euo pipefail

# Kafka Volume Recovery Script - SAFE READ-ONLY VERSION
# Run this on the node where Longhorn volumes are accessible
# 
# SAFETY FEATURES:
# - Read-only mounts only
# - Pre-flight safety checks
# - Automatic cleanup on exit
# - No modifications to original data
# - Confirmation prompts for destructive actions

VOLUME_PATH="/var/lib/longhorn/replicas/pvc-506850a8-e124-46f8-bfea-2ce2a5deaaf3-89f1b3a3"
MOUNT_POINT="/tmp/kafka-recovery-$(date +%s)"  # Unique mount point
VOLUME_IMAGE="volume-head-006.img"
LOOP_DEVICE=""
MOUNTED=false

# Cleanup function - always runs on exit
cleanup() {
    echo "--- Cleanup ---"
    if [[ "$MOUNTED" == "true" ]] && mountpoint -q "$MOUNT_POINT"; then
        echo "Unmounting $MOUNT_POINT..."
        umount "$MOUNT_POINT" || echo "Warning: Failed to unmount"
        rmdir "$MOUNT_POINT" 2>/dev/null || echo "Warning: Could not remove mount point"
    fi
    
    if [[ -n "$LOOP_DEVICE" ]] && losetup "$LOOP_DEVICE" &>/dev/null; then
        echo "Removing loop device $LOOP_DEVICE..."
        losetup -d "$LOOP_DEVICE" || echo "Warning: Failed to remove loop device"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

echo "=== KAFKA VOLUME RECOVERY - SAFE READ-ONLY MODE ==="
echo "Volume path: $VOLUME_PATH"
echo "Mount point: $MOUNT_POINT"
echo ""

# Safety checks
echo "--- Pre-flight Safety Checks ---"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (for loop device access)"
   exit 1
fi

# Check if volume image exists and is readable
if [[ ! -f "$VOLUME_PATH/$VOLUME_IMAGE" ]]; then
    echo "ERROR: Volume image not found at $VOLUME_PATH/$VOLUME_IMAGE"
    exit 1
fi

if [[ ! -r "$VOLUME_PATH/$VOLUME_IMAGE" ]]; then
    echo "ERROR: Cannot read volume image at $VOLUME_PATH/$VOLUME_IMAGE"
    exit 1
fi

# Check available loop devices
if ! losetup -f &>/dev/null; then
    echo "ERROR: No free loop devices available"
    exit 1
fi

# Check if mount point can be created
PARENT_DIR=$(dirname "$MOUNT_POINT")
if [[ ! -w "$PARENT_DIR" ]]; then
    echo "ERROR: Cannot create mount point in $PARENT_DIR"
    exit 1
fi

# Check disk space for safety
AVAILABLE_SPACE=$(df "$PARENT_DIR" | awk 'NR==2 {print $4}')
if [[ $AVAILABLE_SPACE -lt 1048576 ]]; then  # Less than 1GB
    echo "WARNING: Low disk space available in $PARENT_DIR"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✓ All safety checks passed"
echo ""

# Get file info
echo "--- Volume Image Info ---"
file "$VOLUME_PATH/$VOLUME_IMAGE"
ls -lh "$VOLUME_PATH/$VOLUME_IMAGE"
echo ""

# Try to identify filesystem
echo "--- Filesystem Detection ---"
blkid "$VOLUME_PATH/$VOLUME_IMAGE" 2>/dev/null || echo "Could not detect filesystem with blkid"
echo ""

# Create mount point
mkdir -p "$MOUNT_POINT"
echo "Created mount point: $MOUNT_POINT"

# Create loop device (read-only)
echo "--- Creating Read-Only Loop Device ---"
LOOP_DEVICE=$(losetup -f --show --read-only "$VOLUME_PATH/$VOLUME_IMAGE")
echo "Loop device created: $LOOP_DEVICE (READ-ONLY)"

# Verify loop device is read-only
if ! losetup -l "$LOOP_DEVICE" | grep -q "ro"; then
    echo "ERROR: Loop device is not read-only!"
    exit 1
fi

# Try to mount read-only
echo "--- Mounting Volume (Read-Only) ---"
if mount -o ro "$LOOP_DEVICE" "$MOUNT_POINT"; then
    MOUNTED=true
    echo "✓ Successfully mounted $LOOP_DEVICE to $MOUNT_POINT (READ-ONLY)"
    echo ""
    
    # Verify mount is read-only
    if ! mount | grep "$MOUNT_POINT" | grep -q "ro"; then
        echo "ERROR: Mount is not read-only!"
        exit 1
    fi
    
    # Explore Kafka directory structure
    echo "--- Volume Contents ---"
    ls -la "$MOUNT_POINT/"
    echo ""
    
    # Look for Kafka data directory
    if [[ -d "$MOUNT_POINT/kafka" ]]; then
        echo "--- Found Kafka Directory ---"
        ls -la "$MOUNT_POINT/kafka/"
        echo ""
        
        # Look for topic data
        if [[ -d "$MOUNT_POINT/kafka/data" ]]; then
            echo "--- Kafka Data Directory ---"
            find "$MOUNT_POINT/kafka/data" -maxdepth 2 -type d -name "*-*" | head -20
            echo ""
        fi
    fi
    
    # Look for other common Kafka paths
    echo "--- Searching for Kafka Data ---"
    for kafka_path in "/opt/kafka" "/var/kafka" "/data/kafka" "/kafka-logs"; do
        if [[ -d "$MOUNT_POINT$kafka_path" ]]; then
            echo "Found Kafka at: $kafka_path"
            ls -la "$MOUNT_POINT$kafka_path" | head -10
            echo ""
        fi
    done
    
    # Look for .log files (Kafka segments)
    echo "--- Kafka Log Files (first 10) ---"
    find "$MOUNT_POINT" -name "*.log" -type f 2>/dev/null | head -10
    echo ""
    
    # Show disk usage
    echo "--- Volume Usage ---"
    du -sh "$MOUNT_POINT" 2>/dev/null || echo "Could not calculate disk usage"
    df -h "$MOUNT_POINT"
    echo ""
    
    echo "=== RECOVERY COMPLETE ==="
    echo "Volume mounted READ-ONLY at: $MOUNT_POINT"
    echo "You can now safely explore and copy data from this location."
    echo "The volume will be automatically unmounted when this script exits."
    echo ""
    echo "To keep the mount active, press Ctrl+C to cancel cleanup,"
    echo "then manually unmount later with: umount $MOUNT_POINT && losetup -d $LOOP_DEVICE"
    echo ""
    read -p "Press Enter to unmount and cleanup, or Ctrl+C to keep mounted..."
    
else
    echo "ERROR: Failed to mount volume"
    exit 1
fi