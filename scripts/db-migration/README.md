# Database Migration Script

Simple script to migrate individual databases from production to staging using `pg_dump` and `psql`.

## Prerequisites

1. **kubectl access** to both production and staging clusters
2. **Tailscale connectivity** to access database hosts
3. **PostgreSQL client tools** (`pg_dump`, `psql`) installed locally

## Usage

### Dry Run (Test Only)
Validates connectivity and credentials to both databases.
```bash
./migrate-database.sh --database=grafana --production-context=cxs-eu1 --staging-context=cxs-staging --dry-run
```

### Basic Migration
```bash
./migrate-database.sh --database=ssp --production-context=cxs-eu1 --staging-context=cxs-staging
```


## Supported Databases


| Database  | User        | Description                    |
|-----------|-------------|--------------------------------|
| `ssp`     | `cxs-pg`    | Main application database      |
| `grafana` | `grafana`   | Grafana dashboards and config  |
| `n8n`     | `n8n-db`    | N8N workflow automation        |
| `airflow` | `aiflow-db` | Airflow orchestration          |
| `convoy`  | `convoy-db` | Convoy webhook delivery        |

## How It Works

1. **Credential Extraction**: Automatically extracts database credentials from Kubernetes secrets in both clusters
2. **Connection Testing**: Validates connectivity to both production and staging databases
3. **Database Export**: Uses `pg_dump` to export the specified database from production
4. **Database Import**: Uses `psql` to import the database to staging (with confirmation prompt)
5. **Validation**: Compares table counts between production and staging

## Safety Features

### kubectl Context Safety
- Explicit context switching with validation
- Production context used only for read operations (export)
- Staging context requires user confirmation before write operations
- Context validation before each database operation

### Migration Safety
- Dry run mode to test connections without making changes
- User confirmation required before staging import
- Automatic backup file creation with timestamps
- Table count validation after import
- Comprehensive logging of all operations

### Connection Safety
- Uses Tailscale hostnames for secure database access
- Separate credential namespaces (production vs staging)
- Automatic credential cleanup after script completion

## Output Files

### Backup Files
- Location: `.backups/`
- Format: `{database}-YYYYMMDD-HHMMSS.sql`
- Example: `.backups/ssp-20250801-143022.sql`

### Log Files
- Location: `.logs/db-migrations/`
- Format: `database-migration-{database}-YYYYMMDD-HHMMSS.log`
- Example: `.logs/db-migrations/database-migration-ssp-20250801-143022.log`

## Connection Details

The script automatically uses:
- **Production**: `data-cxs-pg-pgbouncer.com:5432` (via Tailscale)
- **Staging**: `data-cxs-pg-pgbouncer-dev.com:5432` (via Tailscale)

Credentials are extracted from Kubernetes secrets:
- Secret name format: `cxs-pg-pguser-{username}`  
- Namespace: `data`

## Examples

### Migrate SSP Database
```bash
./migrate-database.sh --database=ssp --production-context=prod --staging-context=staging
```

### Test Grafana Migration (Dry Run)
```bash
./migrate-database.sh --database=grafana --production-context=prod --staging-context=staging --dry-run
```

## Troubleshooting

### Connection Issues
- Ensure Tailscale is connected and can reach the database hosts
- Verify kubectl contexts are configured and accessible
- Check that database secrets exist in the `data` namespace

### Permission Issues  
- Ensure the database user has appropriate permissions
- For staging imports, the user needs CREATE/DROP privileges
- Check that pgBouncer allows the required operations

### Import Failures
- Check disk space on staging cluster
- Verify staging database exists and is accessible
- Review logs for specific error messages

### Credential Issues
- Verify secret names match expected format: `cxs-pg-pguser-{username}`
- Ensure secrets contain required keys: user, host, password, dbname, port
- Check that kubectl has access to the `data` namespace

## Script Behavior

The script will:
1. ✅ Validate all parameters and contexts
2. ✅ Extract credentials from both clusters  
3. ✅ Test connectivity to both databases
4. ✅ Show table counts and migration summary
5. ⚠️  **Require explicit confirmation before staging import**
6. ✅ Create timestamped backup and log files
7. ✅ Validate migration success

The script will **NOT**:
- ❌ Make any changes in dry-run mode
- ❌ Modify production database (read-only access)
- ❌ Import without explicit user confirmation
- ❌ Continue if any validation step fails