# Minio Tentant Config (STAGING)

## Adding Users
To create users in MinIO, you need to use the MinIO Console:

1. Access the MinIO Console over Tailscale at <http://data-minio-console-dev:9090/>
2. Log in with the admin credentials (see the `minio-admin-credentials` secret in the `data` namespace).
3. Navigate to the "Identity" or "Users" section in the console.
4. Click "Create User" and fill in the required details.
5. Assign appropriate policies/permissions to the new user.
