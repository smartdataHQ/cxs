#!/bin/bash

# App Migration Validation Tool
# Validates that apps are working correctly after database secret migration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
APP_NAME=""
NAMESPACE=""
CONTEXT="cxs-staging"
CHECK_ENDPOINTS=false
CHECK_SECRETS=false
CHECK_LOGS=false
VERBOSE=false

usage() {
    cat << EOF
Usage: $0 <app-name> [OPTIONS]

Validates app health after database secret migration.

OPTIONS:
    --namespace=NS          Target namespace (required)
    --context=CONTEXT       Kubernetes context (default: cxs-staging)
    --check-endpoints       Test application health endpoints
    --check-secrets         Verify secret mounting and references
    --check-logs           Check recent logs for errors
    --verbose              Show detailed output
    --help                 Show this help message

EXAMPLES:
    $0 contextapi --namespace=api --check-endpoints --check-secrets
    $0 cxs-services --namespace=solutions --check-logs --verbose

EOF
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

APP_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace=*)
            NAMESPACE="${1#*=}"
            shift
            ;;
        --context=*)
            CONTEXT="${1#*=}"
            shift
            ;;
        --check-endpoints)
            CHECK_ENDPOINTS=true
            shift
            ;;
        --check-secrets)
            CHECK_SECRETS=true
            shift
            ;;
        --check-logs)
            CHECK_LOGS=true
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

if [[ -z "$NAMESPACE" ]]; then
    echo "Error: --namespace is required"
    usage
    exit 1
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

# Check pod status
check_pod_status() {
    log_info "Checking pod status for $APP_NAME in namespace $NAMESPACE..."
    
    local pods=$(kubectl --context=$CONTEXT get pods -n "$NAMESPACE" -l "app=$APP_NAME" --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$pods" ]]; then
        log_error "No pods found for app '$APP_NAME' in namespace '$NAMESPACE'"
        return 1
    fi
    
    local ready_pods=0
    local total_pods=0
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        
        local pod_name=$(echo "$line" | awk '{print $1}')
        local ready=$(echo "$line" | awk '{print $2}')
        local status=$(echo "$line" | awk '{print $3}')
        
        ((total_pods++))
        
        log_verbose "Pod: $pod_name, Ready: $ready, Status: $status"
        
        if [[ "$status" == "Running" ]] && [[ "$ready" =~ ^[1-9]/[1-9] ]]; then
            ((ready_pods++))
            log_success "Pod $pod_name is running and ready"
        elif [[ "$status" == "CrashLoopBackOff" ]]; then
            log_error "Pod $pod_name is in CrashLoopBackOff"
        else
            log_warning "Pod $pod_name status: $status, ready: $ready"
        fi
    done <<< "$pods"
    
    log_info "Pod summary: $ready_pods/$total_pods pods ready"
    
    if [[ $ready_pods -eq $total_pods ]] && [[ $total_pods -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Check secrets are mounted correctly
check_secrets() {
    if [[ "$CHECK_SECRETS" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking secret references for $APP_NAME..."
    
    # Get first pod
    local pod=$(kubectl --context=$CONTEXT get pods -n "$NAMESPACE" -l "app=$APP_NAME" --no-headers -o custom-columns=:metadata.name | head -1)
    
    if [[ -z "$pod" ]]; then
        log_error "No pods found to check secrets"
        return 1
    fi
    
    log_verbose "Checking secrets in pod: $pod"
    
    # Check if expected database secrets are mounted
    local expected_secrets=("redis-auth" "clickhouse" "cxs-pg-pguser-cxs-pg")
    local secret_check_passed=true
    
    for secret in "${expected_secrets[@]}"; do
        if kubectl --context=$CONTEXT get secret "$secret" -n "$NAMESPACE" >/dev/null 2>&1; then
            log_success "Secret '$secret' exists in namespace '$NAMESPACE'"
        else
            log_error "Secret '$secret' not found in namespace '$NAMESPACE'"
            secret_check_passed=false
        fi
    done
    
    if [[ "$secret_check_passed" == "true" ]]; then
        log_success "All expected database secrets are present"
        return 0
    else
        log_error "Some database secrets are missing"
        return 1
    fi
}

# Check application logs for errors
check_logs() {
    if [[ "$CHECK_LOGS" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking recent logs for $APP_NAME..."
    
    local pod=$(kubectl --context=$CONTEXT get pods -n "$NAMESPACE" -l "app=$APP_NAME" --no-headers -o custom-columns=:metadata.name | head -1)
    
    if [[ -z "$pod" ]]; then
        log_error "No pods found to check logs"
        return 1
    fi
    
    log_verbose "Checking logs for pod: $pod"
    
    # Get recent logs and check for common error patterns
    local logs=$(kubectl --context=$CONTEXT logs "$pod" -n "$NAMESPACE" --tail=50 2>/dev/null || echo "")
    
    if [[ -z "$logs" ]]; then
        log_warning "No recent logs found for pod $pod"
        return 0
    fi
    
    # Check for database connection errors
    if echo "$logs" | grep -qi -E "(connection.*refused|connection.*failed|authentication.*failed|password.*authentication.*failed)"; then
        log_error "Found database connection errors in logs"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$logs" | grep -i -E "(connection|authentication|password)" | head -5
        fi
        return 1
    fi
    
    # Check for general errors
    local error_count=$(echo "$logs" | grep -ci -E "(error|exception|failed)" || echo "0")
    
    if [[ $error_count -gt 0 ]]; then
        log_warning "Found $error_count error-like messages in recent logs"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$logs" | grep -i -E "(error|exception|failed)" | head -3
        fi
    else
        log_success "No obvious errors found in recent logs"
    fi
    
    return 0
}

# Check health endpoints
check_endpoints() {
    if [[ "$CHECK_ENDPOINTS" != "true" ]]; then
        return 0
    fi
    
    log_info "Checking health endpoints for $APP_NAME..."
    
    # Get service information
    local service=$(kubectl --context=$CONTEXT get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}' 2>/dev/null || echo "")
    
    if [[ -z "$service" ]]; then
        log_warning "No service found for $APP_NAME, skipping endpoint checks"
        return 0
    fi
    
    log_verbose "Service endpoint: $service"
    
    # Port forward to test endpoints (in background)
    local local_port=8999
    kubectl --context=$CONTEXT port-forward -n "$NAMESPACE" "service/$APP_NAME" "$local_port:${service#*:}" >/dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Give port-forward time to establish
    sleep 3
    
    # Test common health endpoints
    local endpoints=("/api/status/alive" "/api/status/ready" "/health" "/healthz")
    local endpoint_success=false
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f "http://localhost:$local_port$endpoint" >/dev/null 2>&1; then
            log_success "Health endpoint $endpoint responded successfully"
            endpoint_success=true
            break
        else
            log_verbose "Endpoint $endpoint not responsive"
        fi
    done
    
    # Clean up port-forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [[ "$endpoint_success" == "true" ]]; then
        return 0
    else
        log_warning "No health endpoints responded successfully"
        return 1
    fi
}

# Main validation
main() {
    log_info "Starting validation for app '$APP_NAME' in namespace '$NAMESPACE'"
    log_info "Using context: $CONTEXT"
    echo
    
    local validation_passed=true
    
    # Always check pod status
    if ! check_pod_status; then
        validation_passed=false
    fi
    echo
    
    # Check secrets if requested
    if ! check_secrets; then
        validation_passed=false
    fi
    echo
    
    # Check logs if requested
    if ! check_logs; then
        validation_passed=false
    fi
    echo
    
    # Check endpoints if requested
    if ! check_endpoints; then
        validation_passed=false
    fi
    echo
    
    # Summary
    if [[ "$validation_passed" == "true" ]]; then
        log_success "✅ All validations passed for $APP_NAME"
        exit 0
    else
        log_error "❌ Some validations failed for $APP_NAME"
        exit 1
    fi
}

# Run main function
main "$@"