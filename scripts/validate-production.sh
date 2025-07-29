#!/bin/bash

# Production Overlay Validation Script
# Validates that production overlays match what's running on the cluster

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
APPS_DIR="apps"
OVERLAY_NAME="production"
COMPLETION_DIR=".validation-status"
DIFF_OUTPUT_DIR=".validation-diffs"
VERBOSE=false
SPECIFIC_APPS=""
MARK_COMPLETED=false
EXIT_ON_DIFF=true
SAVE_DIFFS=false
AUTO_OPEN_DIFF=false
DIFF_VIEWER="delta -s"
NAMESPACE_OVERRIDE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_APPS=0
IN_SYNC=0
OUT_OF_SYNC=0
ERRORS=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validates Kubernetes overlays against cluster state using kubectl diff.

OPTIONS:
    -v, --verbose           Show detailed diff output
    -a, --apps=APP1,APP2    Check specific apps only (comma-separated)
    -o, --overlay=NAME      Overlay name to validate (default: production)
    -n, --namespace=NS      Override target namespace (detects from kustomization by default)
    -m, --mark-completed    Create completion markers for in-sync apps
    -c, --continue-on-diff  Continue validation even if diffs are found
    -d, --save-diffs        Save diff output to files for inspection with diff tools
    --auto-open             Automatically open diff with viewer (first diff found)
    --viewer=TOOL           Diff viewer tool (default: delta -s)
    -h, --help             Show this help message

EXAMPLES:
    $0                                    # Validate all production overlays
    $0 --apps=contextsuite,contextapi     # Validate specific apps only
    $0 --overlay=staging                  # Validate staging overlays
    $0 --namespace=api --apps=contextapi  # Override namespace for specific app
    $0 --verbose --mark-completed         # Verbose mode with completion tracking
    $0 --continue-on-diff --save-diffs    # Save diffs and don't exit on first diff
    $0 --overlay=staging --save-diffs     # Validate staging with diff files
    $0 --apps=contextapi --auto-open      # Validate single app and auto-open diff
    $0 --apps=contextapi --auto-open --viewer=bat  # Use bat instead of delta

EXIT CODES:
    0    All apps in sync
    1    Configuration drift detected
    2    Validation errors occurred
    3    No production overlays found
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -a|--apps)
            SPECIFIC_APPS="$2"
            shift 2
            ;;
        --apps=*)
            SPECIFIC_APPS="${1#*=}"
            shift
            ;;
        -o|--overlay)
            OVERLAY_NAME="$2"
            shift 2
            ;;
        --overlay=*)
            OVERLAY_NAME="${1#*=}"
            shift
            ;;
        -n|--namespace)
            NAMESPACE_OVERRIDE="$2"
            shift 2
            ;;
        --namespace=*)
            NAMESPACE_OVERRIDE="${1#*=}"
            shift
            ;;
        -m|--mark-completed)
            MARK_COMPLETED=true
            shift
            ;;
        -c|--continue-on-diff)
            EXIT_ON_DIFF=false
            shift
            ;;
        -d|--save-diffs)
            SAVE_DIFFS=true
            shift
            ;;
        --auto-open)
            AUTO_OPEN_DIFF=true
            SAVE_DIFFS=true  # Auto-enable save-diffs for auto-open
            shift
            ;;
        --viewer)
            DIFF_VIEWER="$2"
            shift 2
            ;;
        --viewer=*)
            DIFF_VIEWER="${1#*=}"
            shift
            ;;
        -h|--help)
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

# Update directory names to include overlay name
COMPLETION_DIR="${COMPLETION_DIR}-${OVERLAY_NAME}"
DIFF_OUTPUT_DIR="${DIFF_OUTPUT_DIR}-${OVERLAY_NAME}"

# Initialize completion directory if marking completed
if [[ "$MARK_COMPLETED" == "true" ]]; then
    mkdir -p "$COMPLETION_DIR"
fi

# Initialize diff output directory if saving diffs
if [[ "$SAVE_DIFFS" == "true" ]]; then
    mkdir -p "$DIFF_OUTPUT_DIR"
    
    # Clean up old diff files for the specific apps being validated to avoid confusion
    if [[ -n "$SPECIFIC_APPS" ]]; then
        IFS=',' read -ra app_list <<< "$SPECIFIC_APPS"
        for app in "${app_list[@]}"; do
            app=$(echo "$app" | xargs) # trim whitespace
            old_diff="$DIFF_OUTPUT_DIR/${app}.diff"
            [[ -f "$old_diff" ]] && rm -f "$old_diff"
        done
    fi
fi

# Function to log with colors
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

# Function to mark app as completed
mark_completed() {
    local app="$1"
    if [[ "$MARK_COMPLETED" == "true" ]]; then
        local completion_path="$SCRIPT_DIR/../$COMPLETION_DIR"
        mkdir -p "$completion_path"
        echo "$(date -Iseconds)" > "$completion_path/${app}.completed"
        log_info "Marked $app as validated"
    fi
}

# Function to check if app is already completed
is_completed() {
    local app="$1"
    local completion_path="$SCRIPT_DIR/../$COMPLETION_DIR"
    [[ -f "$completion_path/${app}.completed" ]]
}

# Function to extract namespace from kustomization files
get_app_namespace() {
    local app_path="$1"
    local app_name=$(basename "$app_path")
    local overlay_path="$app_path/overlays/$OVERLAY_NAME"
    local base_path="$app_path/base"
    
    # Check overlay kustomization first
    if [[ -f "$overlay_path/kustomization.yaml" ]]; then
        local ns=$(grep "^namespace:" "$overlay_path/kustomization.yaml" 2>/dev/null | cut -d: -f2 | xargs)
        if [[ -n "$ns" ]]; then
            echo "$ns"
            return 0
        fi
    fi
    
    # Fall back to base kustomization
    if [[ -f "$base_path/kustomization.yaml" ]]; then
        local ns=$(grep "^namespace:" "$base_path/kustomization.yaml" 2>/dev/null | cut -d: -f2 | xargs)
        if [[ -n "$ns" ]]; then
            echo "$ns"
            return 0
        fi
    fi
    
    # If no namespace found in kustomization, try to detect from cluster
    # Look for a deployment with the app name across all namespaces
    local cluster_ns=$(kubectl get deployments --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null | grep -E "\\s${app_name}\\s*$" | head -1 | awk '{print $1}')
    if [[ -n "$cluster_ns" ]]; then
        echo "$cluster_ns"
        return 0
    fi
    
    # No namespace found
    echo ""
}

# Function to validate a single app
validate_app() {
    local app_path="$1"
    local app_name=$(basename "$app_path")
    local app_overlay="$app_path/overlays/$OVERLAY_NAME"
    
    # Check if overlay exists
    if [[ ! -d "$app_overlay" ]]; then
        log_warning "$app_name: No $OVERLAY_NAME overlay found"
        return 0
    fi
    
    # Check if kustomization.yaml exists
    if [[ ! -f "$app_overlay/kustomization.yaml" ]]; then
        log_error "$app_name: No kustomization.yaml in $OVERLAY_NAME overlay"
        ((ERRORS++))
        return 1
    fi
    
    # Skip if already completed
    if is_completed "$app_name"; then
        log_info "$app_name: Already validated (skipped)"
        return 0
    fi
    
    # Get target namespace for this app
    local target_namespace="$NAMESPACE_OVERRIDE"
    if [[ -z "$target_namespace" ]]; then
        target_namespace=$(get_app_namespace "$app_path")
    fi
    
    if [[ -n "$target_namespace" ]]; then
        log_info "Validating $app_name (namespace: $target_namespace)..."
    else
        log_info "Validating $app_name..."
    fi
    
    # Change to app directory for kubectl diff
    cd "$app_path"
    
    # Run kubectl diff with namespace awareness
    local temp_file=$(mktemp)
    local exit_code=0
    local original_dir=$(pwd)
    local kubectl_cmd="kubectl diff -k overlays/$OVERLAY_NAME"
    
    # Add explicit namespace if we found one
    if [[ -n "$target_namespace" ]]; then
        # Check if namespace exists and is accessible
        if ! kubectl get namespace "$target_namespace" >/dev/null 2>&1; then
            log_warning "$app_name: Target namespace '$target_namespace' not accessible or doesn't exist"
        else
            kubectl_cmd="kubectl diff -k overlays/$OVERLAY_NAME --namespace=$target_namespace"
        fi
    fi
    
    if $kubectl_cmd > "$temp_file" 2>&1; then
        # No differences found
        log_success "$app_name: IN SYNC"
        ((IN_SYNC++))
        mark_completed "$app_name"
    else
        exit_code=$?
        
        if [[ $exit_code -eq 1 ]]; then
            # Differences found (exit code 1 is expected for diffs)
            log_error "$app_name: DRIFT DETECTED"
            ((OUT_OF_SYNC++))
            
            # Save diff to file if requested
            if [[ "$SAVE_DIFFS" == "true" ]]; then
                local diff_file="$SCRIPT_DIR/../$DIFF_OUTPUT_DIR/${app_name}.diff"
                
                # Create a more readable diff by replacing temp file paths
                sed -E "
                    s|^diff -u -N .*/LIVE-[0-9]+/(.*) .*/MERGED-[0-9]+/(.*)$|diff --git a/CLUSTER:\1 b/OVERLAY:\2|g;
                    s|^--- .*/LIVE-[0-9]+/(.*)$|--- a/CLUSTER: \1|g;
                    s|^\+\+\+ .*/MERGED-[0-9]+/(.*)$|+++ b/OVERLAY: \1|g
                " "$temp_file" > "$diff_file"
                
                log_info "Diff saved to: $diff_file"
            fi
            
            if [[ "$VERBOSE" == "true" ]]; then
                echo "--- Diff for $app_name ---"
                cat "$temp_file"
                echo "--- End diff for $app_name ---"
                echo
            fi
            
            if [[ "$EXIT_ON_DIFF" == "true" ]]; then
                rm -f "$temp_file"
                cd - > /dev/null
                return 1
            fi
        else
            # Other error (connection, permissions, etc.)
            log_error "$app_name: VALIDATION ERROR (exit code: $exit_code)"
            ((ERRORS++))
            
            if [[ "$VERBOSE" == "true" ]]; then
                echo "--- Error for $app_name ---"
                cat "$temp_file"
                echo "--- End error for $app_name ---"
                echo
            fi
        fi
    fi
    
    rm -f "$temp_file"
    cd - > /dev/null
    return 0
}

# Main execution
main() {
    log_info "Starting $OVERLAY_NAME overlay validation..."
    echo
    
    # Check if apps directory exists
    if [[ ! -d "$APPS_DIR" ]]; then
        log_error "Apps directory '$APPS_DIR' not found"
        exit 3
    fi
    
    # Get list of apps to validate
    local apps_to_check=()
    
    if [[ -n "$SPECIFIC_APPS" ]]; then
        # Parse comma-separated list
        IFS=',' read -ra app_list <<< "$SPECIFIC_APPS"
        for app in "${app_list[@]}"; do
            app=$(echo "$app" | xargs) # trim whitespace
            if [[ -d "$APPS_DIR/$app" ]]; then
                apps_to_check+=("$APPS_DIR/$app")
            else
                log_warning "App '$app' not found in $APPS_DIR"
            fi
        done
    else
        # Find all apps with the specified overlay
        while IFS= read -r -d '' app_dir; do
            if [[ -d "$app_dir/overlays/$OVERLAY_NAME" ]]; then
                apps_to_check+=("$app_dir")
            fi
        done < <(find "$APPS_DIR" -maxdepth 1 -type d -print0 | sort -z)
    fi
    
    if [[ ${#apps_to_check[@]} -eq 0 ]]; then
        log_error "No apps with $OVERLAY_NAME overlays found"
        exit 3
    fi
    
    TOTAL_APPS=${#apps_to_check[@]}
    log_info "Found $TOTAL_APPS apps with $OVERLAY_NAME overlays"
    echo
    
    # Validate each app
    local validation_failed=false
    for app_path in "${apps_to_check[@]}"; do
        if ! validate_app "$app_path"; then
            validation_failed=true
            if [[ "$EXIT_ON_DIFF" == "true" ]]; then
                break
            fi
        fi
    done
    
    # Print summary
    echo
    echo "========================================="
    echo "           VALIDATION SUMMARY"
    echo "========================================="
    echo "Total apps checked: $TOTAL_APPS"
    echo "✅ In sync: $IN_SYNC"
    echo "❌ Out of sync: $OUT_OF_SYNC"
    echo "⚠️  Errors: $ERRORS"
    
    # Show diff files if any were saved
    if [[ "$SAVE_DIFFS" == "true" && $OUT_OF_SYNC -gt 0 ]]; then
        echo
        echo "📁 Diff files saved to $DIFF_OUTPUT_DIR/:"
        for diff_file in "$DIFF_OUTPUT_DIR"/*.diff; do
            if [[ -f "$diff_file" ]]; then
                local filename=$(basename "$diff_file")
                echo "   - $filename"
            fi
        done
        echo
        echo "💡 Inspect with: delta < $DIFF_OUTPUT_DIR/<app>.diff"
        echo "💡 Or use your preferred diff tool"
    fi
    
    # Auto-open diff if requested and conditions are met  
    if [[ "$AUTO_OPEN_DIFF" == "true" && $OUT_OF_SYNC -gt 0 ]]; then
        # Find the first diff file to open
        local diff_file_to_open=""
        local app_name_to_open=""
        
        # If specific apps were requested, try to open the first one with a diff
        if [[ -n "$SPECIFIC_APPS" ]]; then
            IFS=',' read -ra app_list <<< "$SPECIFIC_APPS"
            for app in "${app_list[@]}"; do
                app=$(echo "$app" | xargs) # trim whitespace
                local candidate_diff="$DIFF_OUTPUT_DIR/${app}.diff"
                if [[ -f "$candidate_diff" ]]; then
                    diff_file_to_open="$candidate_diff"
                    app_name_to_open="$app"
                    break
                fi
            done
        else
            # Find the first available diff file
            for diff_file in "$DIFF_OUTPUT_DIR"/*.diff; do
                if [[ -f "$diff_file" ]]; then
                    diff_file_to_open="$diff_file"
                    app_name_to_open=$(basename "$diff_file" .diff)
                    break
                fi
            done
        fi
        
        if [[ -n "$diff_file_to_open" ]]; then
            echo
            log_info "Auto-opening diff for $app_name_to_open with $DIFF_VIEWER..."
            
            # Different viewers have different input methods
            # Extract first word to determine viewer type, but use full command
            local viewer_cmd="$DIFF_VIEWER"
            local viewer_base=$(echo "$DIFF_VIEWER" | awk '{print $1}')
            
            case "$viewer_base" in
                delta)
                    $viewer_cmd < "$diff_file_to_open"
                    ;;
                bat)
                    $viewer_cmd "$diff_file_to_open"
                    ;;
                less)
                    $viewer_cmd "$diff_file_to_open"
                    ;;
                code|code-insiders)
                    $viewer_cmd "$diff_file_to_open"
                    ;;
                *)
                    # Generic approach - check if base command exists
                    if command -v "$viewer_base" >/dev/null 2>&1; then
                        # Try piping first (for text viewers), fallback to direct file
                        $viewer_cmd < "$diff_file_to_open" 2>/dev/null || $viewer_cmd "$diff_file_to_open"
                    else
                        log_error "Viewer '$viewer_base' not found. Available options: delta, bat, less, code"
                        log_info "You can also use commands with flags like: --viewer='delta -s --theme=gruvbox'"
                    fi
                    ;;
            esac
        else
            echo
            log_warning "Auto-open requested but no diff files found"
            log_info "This usually means all apps are in sync"
        fi
    elif [[ "$AUTO_OPEN_DIFF" == "true" && $OUT_OF_SYNC -eq 0 ]]; then
        echo
        log_info "No diffs to open - all apps are in sync!"
    fi
    echo
    
    # Set exit code based on results
    if [[ $ERRORS -gt 0 ]]; then
        log_error "Validation completed with errors"
        exit 2
    elif [[ $OUT_OF_SYNC -gt 0 ]]; then
        log_error "Configuration drift detected"
        exit 1
    else
        log_success "All $OVERLAY_NAME overlays are in sync!"
        exit 0
    fi
}

# Run main function
main "$@"