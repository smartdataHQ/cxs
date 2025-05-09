# Update secret

The database password is managed by the percona postgresql operator and kept in
a generated secret file. To update it you need to run the following command:

After enabling credentials towards the kubernetes cluster:

```bash
./update-db-secret.sh
```

