#!/bin/bash

# Database Secret Cross-Namespace Sync Tool
# Copies database secrets from data namespace to application namespaces (staging-only)

set -euo pipefail

# Default configuration - STAGING ONLY for safety
SOURCE_NAMESPACE="data"
TARGET_NAMESPACES=("api" "solutions")
STAGING_CONTEXT="cxs-staging"
DRY_RUN=false
VERBOSE=false
DEFAULT_CONFIG_FILE="secret-mappings.txt"
CONFIG_FILE=""
TARGET_NAMESPACE=""  # New: specific target namespace filter

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Copies database secrets from data namespace to application namespaces (STAGING ONLY).
Uses secret mappings from secret-mappings.txt file to control which secrets go to which namespaces.

OPTIONS:
    --source-namespace=NS      Source namespace for database secrets (default: data)
    --target-namespace=NS      Sync only to this specific target namespace (filters mappings)
    --context=CONTEXT          Kubernetes context to use (default: cxs-staging)
    --config=FILE              Load custom secret mappings from file (default: secret-mappings.txt)
    --dry-run                  Show what would be synced without applying changes
    --verbose                  Show detailed output
    --help                     Show this help message

EXAMPLES:
    $0 --dry-run                                          # Preview staging sync (all namespaces)
    $0 --target-namespace=solutions --verbose             # Sync only to solutions namespace
    $0 --target-namespace=api --dry-run                   # Preview sync to api namespace only
    $0 --context=cxs-staging --verbose                    # Verbose staging sync (all namespaces)
    $0 --config=custom-mappings.txt                       # Use custom mappings file

SECRET MAPPINGS FILE FORMAT:
    The script requires a mappings file in format "source_secret:target_namespace" (one per line):
    
    # Redis - used by most applications
    redis-auth:api
    redis-auth:solutions
    
    # ClickHouse - primarily used by data processing apps
    clickhouse:api
    clickhouse:solutions
    
    # PostgreSQL users - map specific database users to namespaces
    cxs-pg-pguser-postgres:api
    cxs-pg-pguser-postgres:solutions
    
    Lines starting with # are comments and will be ignored.
    When --target-namespace is specified, only mappings for that namespace will be processed.

SAFETY NOTE:
    This tool is designed for STAGING environments only. It defaults to cxs-staging context.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source-namespace=*)
            SOURCE_NAMESPACE="${1#*=}"
            shift
            ;;
        --target-namespace=*)
            TARGET_NAMESPACE="${1#*=}"
            shift
            ;;
        --context=*)
            KUBE_CONTEXT="${1#*=}"
            shift
            ;;
        --config=*)
            CONFIG_FILE="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Default to staging context for safety
if [[ -z "${KUBE_CONTEXT:-}" ]]; then
    KUBE_CONTEXT="$STAGING_CONTEXT"
fi

# Default to secret-mappings.txt if no config file specified
if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$DEFAULT_CONFIG_FILE"
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠️]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to check if secret exists
secret_exists() {
    local namespace="$1"
    local secret_name="$2"
    local kubectl_cmd="kubectl --context=$KUBE_CONTEXT get secret $secret_name -n $namespace"
    
    $kubectl_cmd >/dev/null 2>&1
}

# Function to copy entire secret to target namespace
copy_secret() {
    local source_secret="$1"
    local target_namespace="$2"
    local target_secret="${3:-$source_secret}"  # Use same name if not specified
    
    log_verbose "Copying: $SOURCE_NAMESPACE/$source_secret → $target_namespace/$target_secret"
    
    # Check if source secret exists
    if ! secret_exists "$SOURCE_NAMESPACE" "$source_secret"; then
        log_warning "Source secret '$source_secret' not found in namespace '$SOURCE_NAMESPACE'"
        return 1
    fi
    
    # Check if target namespace exists
    if ! kubectl --context=$KUBE_CONTEXT get namespace "$target_namespace" >/dev/null 2>&1; then
        log_warning "Target namespace '$target_namespace' does not exist"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would copy secret '$source_secret' to namespace '$target_namespace' as '$target_secret'"
        return 0
    fi
    
    # Get source secret and copy to target namespace
    local temp_file=$(mktemp)
    log_info "Migrating secret $source_secret to $target_namespace/$target_secret"
    if kubectl --context=$KUBE_CONTEXT get secret "$source_secret" -n "$SOURCE_NAMESPACE" -o yaml > "$temp_file"; then
        # Update namespace and name in the secret YAML
        sed -i.bak -e "s/namespace: $SOURCE_NAMESPACE/namespace: $target_namespace/" \
                   -e "s/name: $source_secret/name: $target_secret/" \
                   -e '/resourceVersion:/d' \
                   -e '/uid:/d' \
                   -e '/creationTimestamp:/d' \
                   "$temp_file"
        
        # Apply the modified secret
        if kubectl --context=$KUBE_CONTEXT apply -f "$temp_file" >/dev/null 2>&1; then
            log_success "Copied secret '$source_secret' to '$target_namespace/$target_secret'"
            rm -f "$temp_file" "$temp_file.bak"
            return 0
        else
            log_error "Failed to copy secret '$source_secret' to '$target_namespace/$target_secret'"
            rm -f "$temp_file" "$temp_file.bak"
            return 1
        fi
    else
        log_error "Failed to read source secret '$source_secret'"
        rm -f "$temp_file" "$temp_file.bak"
        return 1
    fi
}

# Array to store loaded mappings
SECRET_MAPPINGS=()

# Function to load mappings from config file
load_config_mappings() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file '$config_file' not found"
        log_info "Please create a secret-mappings.txt file with mappings in format 'source_secret:target_namespace'"
        return 1
    fi
    
    log_info "Loading secret mappings from: $config_file"
    
    # Clear existing mappings
    SECRET_MAPPINGS=()
    local all_mappings=()
    
    # Load mappings from file (ignore comments and empty lines)
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # Store original line for verbose output (with comments)
        local original_line="$line"
        
        # Strip inline comments for processing
        line="${line%%#*}"
        # Trim leading/trailing whitespace
        line="$(echo "$line" | xargs)"
        
        # Skip if line is empty after comment removal
        if [[ -z "$line" ]]; then
            continue
        fi
        
        # Validate mapping format
        if [[ "$line" =~ ^[^:]+:[^:]+$ ]]; then
            all_mappings+=("$line")
            log_verbose "Found mapping: $original_line"  # Show original with comments
        else
            log_warning "Invalid mapping format ignored: $original_line"
        fi
    done < "$config_file"
    
    # Filter mappings by target namespace if specified
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        log_info "Filtering mappings for target namespace: $TARGET_NAMESPACE"
        for mapping in "${all_mappings[@]}"; do
            local target_ns="${mapping#*:}"
            if [[ "$target_ns" == "$TARGET_NAMESPACE" ]]; then
                SECRET_MAPPINGS+=("$mapping")
                log_verbose "Including mapping: $mapping"
            else
                log_verbose "Excluding mapping: $mapping (target: $target_ns)"
            fi
        done
    else
        SECRET_MAPPINGS=("${all_mappings[@]}")
        log_info "Using all mappings (no target namespace filter)"
    fi
    
    log_info "Loaded ${#SECRET_MAPPINGS[@]} secret mappings from config file"
    
    if [[ ${#SECRET_MAPPINGS[@]} -eq 0 ]]; then
        if [[ -n "$TARGET_NAMESPACE" ]]; then
            log_error "No mappings found for target namespace '$TARGET_NAMESPACE'"
        else
            log_error "No valid mappings found in config file"
        fi
        return 1
    fi
    
    return 0
}

# Function to sync database secrets based on mappings
sync_database_secrets() {
    log_info "Syncing database secrets based on mappings..."
    
    if [[ ${#SECRET_MAPPINGS[@]} -eq 0 ]]; then
        log_warning "No secret mappings defined"
        return 1
    fi
    
    local total_mappings=${#SECRET_MAPPINGS[@]}
    local successful_syncs=0
    local failed_syncs=0
    
    for mapping in "${SECRET_MAPPINGS[@]}"; do
        local source_secret="${mapping%:*}"
        local target_namespace="${mapping#*:}"
        
        if copy_secret "$source_secret" "$target_namespace"; then
            ((successful_syncs++))
        else
            ((failed_syncs++))
        fi
    done
    
    log_info "Sync summary: $successful_syncs succeeded, $failed_syncs failed out of $total_mappings total"
}

# Main execution
main() {
    log_info "Starting database secret sync (STAGING ONLY)..."
    
    log_info "Using Kubernetes context: $KUBE_CONTEXT"
    log_info "Source namespace: $SOURCE_NAMESPACE"
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        log_info "Target namespace filter: $TARGET_NAMESPACE"
    else
        log_info "Target namespace filter: (none - syncing to all mapped namespaces)"
    fi
    log_info "Config file: $CONFIG_FILE"
    
    # Safety check - warn if not using staging context
    if [[ "$KUBE_CONTEXT" != "$STAGING_CONTEXT" ]]; then
        log_warning "WARNING: Using non-staging context '$KUBE_CONTEXT'. This tool is designed for staging only!"
        log_warning "Press Ctrl+C to abort, or wait 5 seconds to continue..."
        sleep 5
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes will be applied"
    fi
    
    # Load mappings from config file (required)
    if ! load_config_mappings "$CONFIG_FILE"; then
        log_error "Failed to load config mappings"
        exit 1
    fi
    
    echo
    sync_database_secrets
    echo
    
    log_success "Database secret sync completed!"
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        log_info "Database secrets synced to namespace: $TARGET_NAMESPACE"
    else
        log_info "Database secrets synced to all mapped namespaces"
    fi
    log_info "Database secrets copied with original names and key structures preserved"
}

# Run main function
main "$@"