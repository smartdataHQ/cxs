# Longhorn MinIO Backup Configuration

This document describes how to configure Longhorn to use MinIO as a backup target with self-signed SSL certificates.

## Overview

Longhorn can backup to MinIO (S3-compatible storage) using HTTPS with self-signed certificates. The key is properly configuring the backup secret with the MinIO certificate.

## Prerequisites

- Longhorn installed and running
- MinIO installed with HTTPS/TLS enabled
- Self-signed certificate for MinIO

## Configuration

### 1. MinIO Certificate Setup

Ensure MinIO is running with proper TLS certificates. The certificates should be:
- Named `public.crt` and `private.key` 
- Located in `/home/minio-user/.minio/certs/` (or the path MinIO expects)
- Include proper Subject Alternative Names for your MinIO endpoints

### 2. Create Longhorn Backup Secret

Create a Kubernetes secret with the following fields:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-backup-credentials
  namespace: longhorn-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <base64-encoded-access-key>
  AWS_SECRET_ACCESS_KEY: <base64-encoded-secret-key>
  AWS_ENDPOINTS: <base64-encoded-https-endpoint>  # https://minio.storage.svc.cluster.local:9025
  AWS_CERT: <base64-encoded-certificate>          # MinIO public certificate in PEM format
  AWS_REGION: <base64-encoded-region>             # minio (or us-east-1)
```

#### Key Configuration Details

- **`AWS_ENDPOINTS`**: Must use HTTPS URL format
- **`AWS_CERT`**: Contains the MinIO public certificate in PEM format (base64 encoded)
- **`AWS_REGION`**: Can be any value (e.g., `minio`, `us-east-1`)

### 3. Configure Backup Target

Set the backup target URL to:
```
s3://backups@minio/longhorn
```

Where:
- `backups` = S3 bucket name
- `minio` = region (matches AWS_REGION in secret)  
- `longhorn` = path within bucket

### 4. Apply Configuration

1. Apply the secret:
   ```bash
   kubectl apply -f minio-backup-credentials.yaml
   ```

2. Update the backup target (via Longhorn UI or kubectl):
   ```bash
   kubectl patch backuptarget default -n longhorn-system --type='merge' \
     -p='{"spec":{"backupTargetURL":"s3://backups@minio/longhorn","credentialSecret":"minio-backup-credentials"}}'
   ```

## Verification

Check that the backup target is available:
```bash
kubectl get backuptargets -n longhorn-system
```

The output should show:
```
NAME      URL                           CREDENTIAL                 AVAILABLE
default   s3://backups@minio/longhorn   minio-backup-credentials   true
```

## Troubleshooting

### Common Issues

1. **Certificate verification failed**
   - Ensure `AWS_CERT` contains the correct MinIO certificate
   - Verify certificate includes proper Subject Alternative Names
   - Certificate must be in PEM format and base64 encoded

2. **Invalid URL format**
   - Use format: `s3://bucket@region/path`
   - Avoid old format with `?sslVerify=false`

3. **Missing region error**
   - Ensure `AWS_REGION` is set in the secret
   - Region can be any value for MinIO

4. **Connection refused**
   - Verify `AWS_ENDPOINTS` uses correct HTTPS URL
   - Check MinIO is accessible from Longhorn pods

### Debug Commands

```bash
# Check backup target status
kubectl get backuptargets -n longhorn-system -o yaml

# View backup target events  
kubectl describe backuptarget default -n longhorn-system

# Check secret contents
kubectl get secret minio-backup-credentials -n longhorn-system -o yaml

# Test connectivity from a pod
kubectl run test-pod --rm -it --image=alpine/curl -- \
  curl -k https://minio.storage.svc.cluster.local:9025/minio/health/live
```

## Security Notes

- Self-signed certificates are acceptable for internal MinIO deployments
- The certificate in `AWS_CERT` allows Longhorn to trust the MinIO endpoint
- HTTPS communication is enforced via `AWS_ENDPOINTS`
- Consider using proper CA-signed certificates for production environments

## Example Secret Generation

```bash
# Get MinIO certificate
MINIO_CERT=$(kubectl exec -n data cxs-pg-repo-host-0 -- cat /path/to/public.crt | base64 -w 0)

# Create secret
kubectl create secret generic minio-backup-credentials -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID=your-access-key \
  --from-literal=AWS_SECRET_ACCESS_KEY=your-secret-key \
  --from-literal=AWS_ENDPOINTS=https://minio.storage.svc.cluster.local:9025 \
  --from-literal=AWS_CERT="${MINIO_CERT}" \
  --from-literal=AWS_REGION=minio
```