# Restoring a DB cluster

This document outlines how to restore a Postgres db snapshot to a **NEW**, temporary cluster that is spun up beside the
real cluster using the Percona Postgres Operator.

**NOTE**: This document **DOES NOT** cover how to restore a Database "in-place".

## ⚠️ Important: Rancher Fleet Behavior

**Fleet automatically deploys ALL `.yaml` files it finds in this repository.** To prevent accidental deployment of restore configurations, all YAML files in this directory use the `.txt` extension.

**When using the templates, you MUST rename them back to `.yaml` before applying to kubectl.**

## Prequisites

This guide assumes the following

- kubectl access to `prod`
- Tailscale access

### IMPORTANT: The PerconaPGCluster Name Identifier

The `metadata.name` you choose for your PerconaPGCluster resource is **CRITICAL** as it becomes the identifier used
throughout the entire system:

- **Kubernetes Secret Name**: `<name>-pguser-cxs-pg`
- **Tailscale Hostname**: Available at `<name>` on the Tailscale network
- **Resource References**: Used in all kubectl commands and resource lookups

**Choose wisely!** Use a clear, timestamped name like `cxs-pg-restore-20250723` to avoid confusion with production
resources.

## 1. Get the snapshot ID to with to restore to

Run:

```
$ kubectl exec -ndata cxs-pg-repo-host-0 -- pgbackrest info
```

You will get output akin to the following:

```
    [...]
    full backup: 20250714-060008F
        timestamp start/stop: 2025-07-14 06:00:08+00 / 2025-07-14 06:01:49+00
        wal start/stop: 0000001800000A5300000005 / 0000001800000A5300000006
        database size: 947.1MB, database backup size: 947.1MB
        repo1: backup set size: 401.5MB, backup size: 401.5MB

    diff backup: 20250714-060008F_20250715-060008D
        timestamp start/stop: 2025-07-15 06:00:08+00 / 2025-07-15 06:01:55+00
        wal start/stop: 0000001800000A5900000069 / 0000001800000A590000006A
        database size: 1.2GB, database backup size: 1GB
        repo1: backup set size: 639.7MB, backup size: 610.4MB
        backup reference list: 20250714-060008F
    [...]
 ```

The snapshot ID has a different format depending on the backup type, but in the list above the available ID's are:

- `20250714-060008F` for the last **full** backup
- `20250714-060008F_20250715-060008D` - for the last **differential** backup

## 2. Prepare the `PerconaPGCluster` YAML.

Create a timestamped copy of [restore-db-template.yaml.txt](./restore-db-template.yaml.txt) (rename to `.yaml`) and update:

- `metadata.name`
    - Just append a date / timestamp
    - Don't touch the `&tailscale_hostname` identifier (it's a yaml anchor used below)
    - For the purposes of this document we will use `cxs-pg-restore-20250723`
- `spec.dataSource.postgresCluster.options`
    - Update the `--set` parameter with your Snapshot ID from Step 1.
    - _Optionally_, update, remove or leave the `--db-include` directive based on your needs.

## 3. Apply the YAML

**Important**: Ensure your file has a `.yaml` extension before applying:

```.bash
$ kubectl apply -ndata -f <path-to-your-yaml-file>
```

### Now wait for the Operator to spin up your backup (takes a few minutes)

Once up, you should see some pods:

```.bash
$ kubectl  get pods -ndata  | grep cxs-pg-restore
cxs-pg-restore-20250723-backup-wwh5-cs4kd            0/1     Completed   0              7m
cxs-pg-restore-20250723-instance2-6466-0             4/4     Running     0              7m
cxs-pg-restore-20250723-pgbouncer-6997647b57-2zq7g   2/2     Running     0              7m
cxs-pg-restore-20250723-repo-host-0                  2/2     Running     0              7m
```

The first pod is the restore "job", the rest are cluster pods.

Time to try an connect.


## 4. Retrieve connection info

The Operator will create new credentials and put them in a kubernetes secret named
`<restore-name>-pguser-cxs-pg` where `<restore-name>` is the name you supplied to the PerconaPGCluster resource.

For the purposes of this guide, that name was `cxs-pg-restore-20250723`.

Furthermore, the database will be available over Tailscale using that same identifier.

### Hostname

The postgres cluster should be available over Tailscale under the same PerconaPGCluster resource name, which for the
purposes of this guide was: `cxs-pg-restore-20250723`

### Credentials

#### Configure your secret name:

```
export PG_RESTORE_NAME=<restore name>
export PG_RESTORE_SECRET_NAME="$PG_RESTORE_NAME-pguser-cxs-pg"
```

#### Get Username:

```.bash
$ kubectl get secret -ndata $PG_RESTORE_SECRET_NAME -ojsonpath='{.data.password}' | base64 --decode
```

#### Get Password:

```.bash
$ kubectl get secret -ndata $PG_RESTORE_SECRET_NAME -ojsonpath='{.data.password}' | base64 --decode
```

#### Fetch all credentials:

```.bash
$ kubectl get secret -ndata $PG_RESTORE_SECRET_NAME -o json |   jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
```

### Connect

Having gathered the credentials and connection info, fire up your Database client of choice and try to connect.

**Remember**: You need to be connected via Tailscale to be able to connect.

## 5. Cleanup

Once the restore has been used, delete the PerconaPGCluster resource the same way you created it:

```.bash
$ kubectl delete -ndata -f <path-to-your-yaml-file>
```
