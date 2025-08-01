#!/bin/bash

set -euo pipefail

# Database Migration Script
# Migrates a single database from production to staging using pg_dump/psql
# Usage: ./migrate-database.sh --database=ssp --production-context=prod --staging-context=staging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DATABASE=""
PRODUCTION_CONTEXT=""
STAGING_CONTEXT=""
DRY_RUN=false
LOG_FILE=""

# Database to user mapping (based on your PostgreSQL cluster config)
declare -A DB_USERS=(
    ["ssp"]="cxs-pg"
    ["grafana"]="grafana"
    ["n8n"]="n8n-db"
    ["airflow"]="aiflow-db"
    ["convoy"]="convoy-db"
)

# Tailscale hostnames
PRODUCTION_HOST="data-cxs-pg-pgbouncer.com"
STAGING_HOST="data-cxs-pg-pgbouncer-dev.com"
DB_PORT="5432"

usage() {
    cat << EOF
Usage: $0 --database=DB_NAME --production-context=PROD_CTX --staging-context=STAGING_CTX [OPTIONS]

Required:
  --database=NAME           Database to migrate (ssp, grafana, n8n, airflow, convoy)
  --production-context=CTX  kubectl context for production cluster
  --staging-context=CTX     kubectl context for staging cluster

Options:
  --dry-run                 Test connections only, no actual migration
  --help                    Show this help message

Examples:
  $0 --database=ssp --production-context=prod --staging-context=staging
  $0 --database=grafana --production-context=prod --staging-context=staging --dry-run
EOF
    exit 1
}

log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

log_error() {
    log "${RED}ERROR: $1${NC}"
}

log_success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

log_warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

log_info() {
    log "${BLUE}INFO: $1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database=*)
            DATABASE="${1#*=}"
            shift
            ;;
        --production-context=*)
            PRODUCTION_CONTEXT="${1#*=}"
            shift
            ;;
        --staging-context=*)
            STAGING_CONTEXT="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$DATABASE" || -z "$PRODUCTION_CONTEXT" || -z "$STAGING_CONTEXT" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

# Validate database name
if [[ ! -v DB_USERS[$DATABASE] ]]; then
    echo "Error: Unknown database '$DATABASE'. Supported databases: ${!DB_USERS[*]}"
    exit 1
fi

# Set up logging
mkdir -p logs
LOG_FILE="logs/database-migration-${DATABASE}-$(date +%Y%m%d-%H%M%S).log"

log_info "Starting database migration for: $DATABASE"
log_info "Production context: $PRODUCTION_CONTEXT"
log_info "Staging context: $STAGING_CONTEXT"
log_info "Dry run: $DRY_RUN"
log_info "Log file: $LOG_FILE"

# Get database user
DB_USER=${DB_USERS[$DATABASE]}
log_info "Database user: $DB_USER"

# Function to validate kubectl context
validate_context() {
    local context=$1
    local context_type=$2
    
    log_info "Validating kubectl context: $context ($context_type)"
    
    if ! kubectl config get-contexts "$context" >/dev/null 2>&1; then
        log_error "kubectl context '$context' not found"
        exit 1
    fi
    
    kubectl config use-context "$context" >/dev/null
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to cluster using context '$context'"
        exit 1
    fi
    
    log_success "Context '$context' validated and active"
}

# Function to extract database credentials
extract_credentials() {
    local context=$1
    local context_type=$2
    local secret_name="cxs-pg-pguser-${DB_USER}"
    
    log_info "Extracting credentials from context '$context' (secret: $secret_name)"
    
    validate_context "$context" "$context_type"
    
    if ! kubectl get secret "$secret_name" -n data >/dev/null 2>&1; then
        log_error "Secret '$secret_name' not found in data namespace"
        exit 1
    fi
    
    local user host password dbname port
    user=$(kubectl get secret "$secret_name" -n data -o jsonpath='{.data.user}' | base64 -d)
    host=$(kubectl get secret "$secret_name" -n data -o jsonpath='{.data.host}' | base64 -d)
    password=$(kubectl get secret "$secret_name" -n data -o jsonpath='{.data.password}' | base64 -d)
    dbname=$(kubectl get secret "$secret_name" -n data -o jsonpath='{.data.dbname}' | base64 -d)
    port=$(kubectl get secret "$secret_name" -n data -o jsonpath='{.data.port}' | base64 -d)
    
    if [[ "$context_type" == "production" ]]; then
        export PROD_DB_USER="$user"
        export PROD_DB_HOST="$PRODUCTION_HOST"  # Use Tailscale hostname
        export PROD_DB_PASSWORD="$password"
        export PROD_DB_NAME="$dbname"
        export PROD_DB_PORT="$port"
        log_success "Production credentials extracted (host: $PROD_DB_HOST, user: $PROD_DB_USER, db: $PROD_DB_NAME)"
    else
        export STAGING_DB_USER="$user"
        export STAGING_DB_HOST="$STAGING_HOST"  # Use Tailscale hostname
        export STAGING_DB_PASSWORD="$password"
        export STAGING_DB_NAME="$dbname"
        export STAGING_DB_PORT="$port"
        log_success "Staging credentials extracted (host: $STAGING_DB_HOST, user: $STAGING_DB_USER, db: $STAGING_DB_NAME)"
    fi
}

# Function to test database connection
test_connection() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local dbname=$5
    local context_type=$6
    
    log_info "Testing $context_type database connection (host: $host, db: $dbname)"
    
    export PGPASSWORD="$password"
    if psql -h "$host" -p "$port" -U "$user" -d "$dbname" -c "SELECT version();" >/dev/null 2>&1; then
        log_success "$context_type database connection successful"
        return 0
    else
        log_error "$context_type database connection failed"
        return 1
    fi
}

# Function to get table count
get_table_count() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local dbname=$5
    
    export PGPASSWORD="$password"
    psql -h "$host" -p "$port" -U "$user" -d "$dbname" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | xargs
}

# Function to export database
export_database() {
    local backup_file="backups/${DATABASE}-$(date +%Y%m%d-%H%M%S).sql"
    
    log_info "Exporting production database to: $backup_file"
    mkdir -p backups
    
    export PGPASSWORD="$PROD_DB_PASSWORD"
    if pg_dump -h "$PROD_DB_HOST" -p "$PROD_DB_PORT" -U "$PROD_DB_USER" -d "$PROD_DB_NAME" -f "$backup_file"; then
        log_success "Database export completed: $backup_file"
        local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        log_info "Backup file size: $file_size"
        echo "$backup_file"  # Return the backup file path
    else
        log_error "Database export failed"
        exit 1
    fi
}

# Function to import database
import_database() {
    local backup_file=$1
    
    log_warning "About to import database to STAGING cluster"
    log_warning "This will overwrite the existing '$DATABASE' database in staging"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo -n "Type 'CONFIRM' to proceed with import: "
        read -r confirmation
        if [[ "$confirmation" != "CONFIRM" ]]; then
            log_info "Import cancelled by user"
            exit 0
        fi
    fi
    
    log_info "Importing database from: $backup_file"
    
    export PGPASSWORD="$STAGING_DB_PASSWORD"
    if psql -h "$STAGING_DB_HOST" -p "$STAGING_DB_PORT" -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -f "$backup_file"; then
        log_success "Database import completed"
    else
        log_error "Database import failed"
        exit 1
    fi
}

# Main execution
main() {
    log_info "=== Database Migration Started ==="
    
    # Step 1: Extract credentials
    log_info "Step 1: Extracting credentials"
    extract_credentials "$PRODUCTION_CONTEXT" "production"
    extract_credentials "$STAGING_CONTEXT" "staging"
    
    # Step 2: Test connections
    log_info "Step 2: Testing database connections"
    if ! test_connection "$PROD_DB_HOST" "$PROD_DB_PORT" "$PROD_DB_USER" "$PROD_DB_PASSWORD" "$PROD_DB_NAME" "production"; then
        exit 1
    fi
    
    if ! test_connection "$STAGING_DB_HOST" "$STAGING_DB_PORT" "$STAGING_DB_USER" "$STAGING_DB_PASSWORD" "$STAGING_DB_NAME" "staging"; then
        exit 1
    fi
    
    # Get initial table counts
    local prod_tables staging_tables_before
    prod_tables=$(get_table_count "$PROD_DB_HOST" "$PROD_DB_PORT" "$PROD_DB_USER" "$PROD_DB_PASSWORD" "$PROD_DB_NAME")
    staging_tables_before=$(get_table_count "$STAGING_DB_HOST" "$STAGING_DB_PORT" "$STAGING_DB_USER" "$STAGING_DB_PASSWORD" "$STAGING_DB_NAME")
    
    log_info "Production database tables: $prod_tables"
    log_info "Staging database tables (before): $staging_tables_before"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Dry run completed successfully - all connections working"
        log_info "=== Dry Run Completed ==="
        return 0
    fi
    
    # Step 3: Export database
    log_info "Step 3: Exporting production database"
    validate_context "$PRODUCTION_CONTEXT" "production"
    local backup_file
    backup_file=$(export_database)
    
    # Step 4: Import database  
    log_info "Step 4: Importing to staging database"
    validate_context "$STAGING_CONTEXT" "staging"
    import_database "$backup_file"
    
    # Step 5: Validation
    log_info "Step 5: Post-migration validation"
    local staging_tables_after
    staging_tables_after=$(get_table_count "$STAGING_DB_HOST" "$STAGING_DB_PORT" "$STAGING_DB_USER" "$STAGING_DB_PASSWORD" "$STAGING_DB_NAME")
    
    log_info "Staging database tables (after): $staging_tables_after"
    
    if [[ "$prod_tables" == "$staging_tables_after" ]]; then
        log_success "Table count validation passed: $staging_tables_after tables"
    else
        log_warning "Table count mismatch - Production: $prod_tables, Staging: $staging_tables_after"
    fi
    
    log_success "=== Database Migration Completed Successfully ==="
    log_info "Database: $DATABASE"
    log_info "Backup file: $backup_file"
    log_info "Log file: $LOG_FILE"
}

# Run main function
main

# Clean up environment variables
unset PGPASSWORD PROD_DB_PASSWORD STAGING_DB_PASSWORD