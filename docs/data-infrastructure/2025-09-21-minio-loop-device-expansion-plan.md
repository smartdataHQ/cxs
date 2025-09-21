# MinIO Loop Device Expansion Plan

## Objective
Expand MinIO storage from 100GB to 1TB per node across all three data layer hosts (c001db1, c001db2, c001db3) to restore backup operations and provide adequate capacity for pgBackRest and Longhorn backups.

## Current State
- **Affected hosts**: c001db1, c001db2, c001db3
- **Current capacity**: 100GB per node (300GB cluster total)
- **Target capacity**: 1TB per node (3TB cluster total)
- **Current status**: c001db1 at 100% usage (93GB used), others unknown
- **Impact**: Backup systems failing due to insufficient space

## Prerequisites

### System Requirements
- **Available space**: 13TB+ free space per host (verified on c001db1)
- **Maintenance window**: Estimated 30-60 minutes total downtime
- **Coordination**: All 3 nodes must be processed together
- **Backup verification**: Ensure critical ClickHouse backups exist externally before proceeding

### Pre-flight Checks
```bash
# Verify current state on all nodes
for host in c001db{1..3}; do
    echo "=== $host ==="
    ssh $host "df -h /var/lib/minio/disk1"
    ssh $host "losetup -l"
    ssh $host "ls -lh /mnt/minio-disk1.img"
done

# Verify available space
for host in c001db{1..3}; do
    echo "=== $host available space ==="
    ssh $host "df -h /"
done

# Check MinIO cluster status
kubectl exec -n data cxs-pg-repo-host-0 -- curl -k https://minio.storage.svc.cluster.local:9025/minio/health/cluster
```

## Expansion Procedure

### Phase 1: Preparation (5 minutes)

#### Step 1.1: Verify Cluster Health
```bash
# Check MinIO cluster status
mc admin info minio-cluster

# Verify current usage across all nodes
for host in c001db{1..3}; do
    ssh $host "du -sh /var/lib/minio/disk1"
done
```

#### Step 1.2: Notify Stakeholders
- Alert teams that backup operations will be temporarily unavailable
- Confirm no critical backup operations are scheduled during maintenance window

### Phase 2: Cluster Shutdown (5 minutes)

#### Step 2.1: Stop MinIO Services (Coordinated)
```bash
# Stop MinIO service on all nodes simultaneously
for host in c001db{1..3}; do
    echo "Stopping MinIO on $host"
    ssh $host "sudo systemctl stop minio.service" &
done
wait

# Verify all services stopped
for host in c001db{1..3}; do
    ssh $host "systemctl is-active minio.service || echo 'Stopped'"
done
```

#### Step 2.2: Verify Clean Shutdown
```bash
# Ensure no MinIO processes running
for host in c001db{1..3}; do
    ssh $host "pgrep minio || echo 'No minio processes'"
done
```

### Phase 3: Detach Loop Devices (5 minutes)

#### Step 3.1: Unmount and Detach Loop Devices (CRITICAL SAFETY STEP)
```bash
# Properly detach loop devices before backup and expansion
for host in c001db{1..3}; do
    echo "=== Detaching loop device on $host ==="
    ssh $host "
        echo 'Current loop devices:'
        losetup -l
        
        echo 'Unmounting MinIO disk...'
        umount /var/lib/minio/disk1
        
        echo 'Detaching loop device...'
        losetup -d /dev/loop0
        
        echo 'Verifying detachment:'
        losetup -l | grep loop0 || echo 'Loop device successfully detached'
    "
done
```

### Phase 4: Backup Current Images (10-15 minutes)

#### Step 4.1: Create Backup Directory
```bash
# Create backup location with timestamp
BACKUP_DIR="/root/minio-backup-$(date +%Y%m%d-%H%M%S)"

for host in c001db{1..3}; do
    ssh $host "mkdir -p $BACKUP_DIR"
done
```

#### Step 4.2: Backup Disk Images (SAFE - Loop Devices Detached)
```bash
# Backup existing disk images in parallel (93GB each, ~5-10 minutes total)
# SAFE: Loop devices are detached, filesystem is unmounted
for host in c001db{1..3}; do
    {
        echo "=== Backing up disk image on $host ==="
        ssh $host "
            mkdir -vp $BACKUP_DIR
            echo 'Creating backup of /mnt/minio-disk1.img...'
            cp -v /mnt/minio-disk1.img $BACKUP_DIR/minio-disk1-backup.img
            
            echo 'Verifying backup integrity...'
            ls -lh $BACKUP_DIR/minio-disk1-backup.img
            md5sum /mnt/minio-disk1.img $BACKUP_DIR/minio-disk1-backup.img
        "
    } &
done
wait
```

### Phase 5: Loop Device Expansion (15-20 minutes)

#### Step 5.1: Expand Image Files (SAFER METHOD)
```bash
# Expand each disk image from 100GB to 1TB in parallel (add 900GB)
for host in c001db{1..3}; do
    {
        echo "=== Expanding disk image on $host ==="
        ssh $host "
            echo 'Current image size:'
            ls -lh /mnt/minio-disk1.img
            
            echo 'Available space check:'
            df -h /mnt
            
            echo 'Expanding image by 900GB...'
            dd if=/dev/zero bs=1G count=900 >> /mnt/minio-disk1.img
            
            echo 'New image size:'
            ls -lh /mnt/minio-disk1.img
        "
    } &
done
wait
```

#### Step 5.2: Re-attach and Resize Filesystems
```bash
# Re-attach loop devices and resize filesystems in parallel
for host in c001db{1..3}; do
    {
        echo "=== Re-attaching and resizing on $host ==="
        ssh $host "
            echo 'Re-attaching loop device...'
            losetup /dev/loop0 /mnt/minio-disk1.img
            
            echo 'Checking filesystem before resize...'
            e2fsck -f /dev/loop0
            
            echo 'Resizing filesystem...'
            resize2fs /dev/loop0
            
            echo 'Re-mounting disk...'
            mount /dev/loop0 /var/lib/minio/disk1
            
            echo 'Verifying new capacity:'
            df -h /var/lib/minio/disk1
        "
    } &
done
wait
```

#### Step 5.3: Verify Expansion
```bash
# Confirm new capacity on all nodes in parallel
for host in c001db{1..3}; do
    {
        echo "=== Final capacity on $host ==="
        ssh $host "df -h /var/lib/minio/disk1"
        ssh $host "losetup -l"
    } &
done
wait
```

### Phase 6: Service Restart (5-10 minutes)

#### Step 6.1: Start MinIO Services
```bash
# Start MinIO services in parallel (faster cluster formation)
for host in c001db{1..3}; do
    {
        echo "Starting MinIO on $host"
        ssh $host "sudo systemctl start minio.service"
    } &
done
wait
echo "Waiting for cluster formation..."
sleep 30
```

#### Step 6.2: Verify Service Health
```bash
# Check service status in parallel
for host in c001db{1..3}; do
    {
        echo "=== Service status on $host ==="
        ssh $host "systemctl status minio.service --no-pager"
    } &
done
wait
```

### Phase 7: Verification (10 minutes)

#### Step 7.1: Cluster Health Check
```bash
# Test MinIO cluster connectivity
kubectl exec -n data cxs-pg-repo-host-0 -- curl -k https://minio.storage.svc.cluster.local:9025/minio/health/live

# Check cluster status
mc admin info minio-cluster
```

#### Step 7.2: Capacity Verification
```bash
# Verify new storage capacity in parallel
for host in c001db{1..3}; do
    {
        echo "=== $host final status ==="
        ssh $host "df -h /var/lib/minio/disk1"
    } &
done
wait

# Check MinIO reports correct capacity
mc admin info minio-cluster | grep -i capacity
```

#### Step 7.3: Functional Testing
```bash
# Test basic operations
mc ls minio-cluster/

# Test write operation
echo "test-$(date)" | mc pipe minio-cluster/backups/expansion-test.txt

# Test read operation
mc cat minio-cluster/backups/expansion-test.txt

# Cleanup test file
mc rm minio-cluster/backups/expansion-test.txt
```

## Post-Expansion Verification

### Backup System Testing
```bash
# Verify Longhorn backup target
kubectl get backuptargets -n longhorn-system

# Test pgBackRest backup (if safe to run)
kubectl exec -n data cxs-pg-repo-host-0 -- pgbackrest info --stanza=db --repo=2
```

### Monitoring Setup
```bash
# Monitor storage usage
watch 'for host in c001db{1..3}; do echo "=== $host ==="; ssh $host "df -h /var/lib/minio/disk1"; done'

# Monitor MinIO logs for any issues
for host in c001db{1..3}; do
    ssh $host "journalctl -u minio.service -f" &
done
```

## Rollback Plan

### If Image Expansion Fails
```bash
# Find backup directory
BACKUP_DIR=$(ssh $HOST "ls -d /root/minio-backup-* | tail -1")

# Restore original image
ssh $HOST "
    # Detach current loop device if attached
    losetup -d /dev/loop0 2>/dev/null || true
    
    # Restore from backup
    cp $BACKUP_DIR/minio-disk1-backup.img /mnt/minio-disk1.img
    
    # Re-attach and mount
    losetup /dev/loop0 /mnt/minio-disk1.img
    mount /dev/loop0 /var/lib/minio/disk1
    
    # Restart MinIO
    systemctl start minio.service
"
```

### If Filesystem Resize Fails
```bash
# Restore from backup (safest option)
BACKUP_DIR=$(ssh $HOST "ls -d /root/minio-backup-* | tail -1")

ssh $HOST "
    # Stop service and detach
    systemctl stop minio.service
    umount /var/lib/minio/disk1
    losetup -d /dev/loop0
    
    # Restore backup
    cp $BACKUP_DIR/minio-disk1-backup.img /mnt/minio-disk1.img
    
    # Re-attach and restart
    losetup /dev/loop0 /mnt/minio-disk1.img  
    mount /dev/loop0 /var/lib/minio/disk1
    systemctl start minio.service
"
```

### If Service Won't Start After Expansion
```bash
# Check filesystem integrity
ssh $HOST "
    systemctl stop minio.service
    umount /var/lib/minio/disk1
    e2fsck -f /dev/loop0
    mount /dev/loop0 /var/lib/minio/disk1
    systemctl start minio.service
"

# If still failing, restore from backup
BACKUP_DIR=$(ssh $HOST "ls -d /root/minio-backup-* | tail -1")
ssh $HOST "
    systemctl stop minio.service
    umount /var/lib/minio/disk1
    losetup -d /dev/loop0
    cp $BACKUP_DIR/minio-disk1-backup.img /mnt/minio-disk1.img
    losetup /dev/loop0 /mnt/minio-disk1.img
    mount /dev/loop0 /var/lib/minio/disk1  
    systemctl start minio.service
"
```

## Expected Results

### Capacity Changes
- **Per node**: 100GB → 1TB (10x increase)
- **Cluster total**: 300GB → 3TB raw capacity
- **Usable space**: ~2.8TB (accounting for MinIO erasure coding overhead)

### Service Impact
- **Downtime**: 30-60 minutes total
- **Backup restoration**: pgBackRest and Longhorn operations resume
- **Performance**: No significant change expected
- **Monitoring**: Watch for initial rebalancing activity

## Risk Mitigation

### During Expansion
- **Sequential processing**: Handle one critical step at a time
- **Verification at each step**: Confirm success before proceeding
- **Rollback ready**: Procedures documented for quick recovery

### Post-Expansion
- **Monitoring**: Watch for filesystem stability issues
- **Backup verification**: Ensure backup systems resume normally
- **Capacity alerts**: Set up monitoring for future growth

## Success Criteria

### Technical Success
- [x] All 3 nodes show 1TB MinIO capacity
- [x] MinIO cluster status healthy
- [x] No filesystem corruption detected
- [x] Services start cleanly without errors

### Operational Success  
- [x] pgBackRest backups resume to repo2
- [x] Longhorn backups complete successfully
- [x] No data loss or corruption detected
- [x] Performance within expected parameters

## Timeline

| Phase | Duration | Critical Path |
|-------|----------|---------------|
| Preparation | 5 min | Verification checks |
| Shutdown | 5 min | Coordinated service stop |
| **Backup** | **15 min** | **Image backup creation** |
| Expansion | 20-25 min | Detach + expand + reattach + resize |
| Restart | 5-10 min | Service startup + cluster formation |
| Verification | 10 min | Health checks + testing |
| **Total** | **60-80 min** | **Complete procedure** |

## Communication Plan

### Before Expansion
- Notify backup system stakeholders of maintenance window
- Confirm no critical backup operations scheduled
- Verify emergency contacts available

### During Expansion
- Update progress in operations channel
- Report any deviations from plan immediately
- Escalate if rollback procedures needed

### After Expansion
- Confirm successful completion
- Verify backup systems operational
- Schedule follow-up monitoring check