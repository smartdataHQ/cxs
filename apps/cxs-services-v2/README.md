# CXS Services V2

## Purpose
[Please fill in a brief description of what CXS Services provides. This appears to be a general backend application or a collection of microservices for the Context Suite (CXS).]

## Configuration
Configuration for CXS Services is managed using Kustomize.
- Base configuration is located in the `base/` directory.
- Environment-specific configurations (e.g., staging) are managed via overlays in the `overlays/` directory.

**Important:** No secrets are stored in this repository. Secrets are managed in Rancher and injected into the cluster at deployment time. Refer to the main project `README.md` for more details on secret management.

## Deployment
This application is deployed automatically by Fleet when changes are pushed to this repository. The Fleet configuration for this application can be found in `fleet.yaml`.

## Kubernetes Resources
The base configuration defines the following Kubernetes resources:
- `cxs-services-deployment.yaml`: Manages the deployment of the CXS Services pods.
- `cxs-services-service.yaml`: Exposes the CXS Services internally within the cluster.
- `cxs-services-volumes.yaml`: Defines volume configurations for CXS Services, if any.
- `kustomization.yaml`: Defines the Kustomize configuration for the base layer.

## Minio 
This service depends on minio for the following:

1. A bucket called `rag-content-processing`
2. A User 
3. An Access Key and Secret Key for this User
2. The following policy on this bucket assigned to the User:
    ```.json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:PutObjectTagging",
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::rag-content-processing",
                    "arn:aws:s3:::rag-content-processing/*"
                ]
            }
        ]
    }
    ```
3. These need to be represented in a Secret inside the cluster with the following keys:

```.yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: cxs-services-minio
  namespace: solutions
data:
  MINIO_ACCESS_KEY: KXiI2NNFwDnGNEUssx1d
  MINIO_SECRET_KEY: 5hdexsncEV0ZlUV2UyJtFpDCMxEq8lvQHYzLRRMZ
  MINIO_BUCKET_NAME: rag-content-processing
  MINIO_ENDPOINT: minio.data
```

```bash
export BUCKET_NAME="rag-content-processing"
export ENDPOINT="minio.data"
export MINIO_ACCESS_KEY=<access key>
export MINIO_SECRET_KEY=<secret key>
# Generate the secret
kubectl create secret generic cxs-services-minio \
  --namespace=solutions \
  --from-literal=MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
  --from-literal=MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
  --from-literal=MINIO_BUCKET_NAME="$BUCKET_NAME" \
  --from-literal=MINIO_ENDPOINT="$ENDPOINT" \
  --from-literal=MINIO_SECURE="false"
```

