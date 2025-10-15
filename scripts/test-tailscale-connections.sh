#!/bin/bash

# Tailscale Connection Testing Script
# Tests connectivity to all exposed Tailscale hosts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_FILE="${SCRIPT_DIR}/../tailscale-hosts.conf"
TIMEOUT=3
DOMAIN_SUFFIX=".tail94c3e1.ts.net"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test HTTP/HTTPS connection
test_http_connection() {
    local hostname="$1"
    local port="$2"
    local path="${3:-/}"
    local protocol="${4:-http}"
    
    local full_url="${protocol}://${hostname}${DOMAIN_SUFFIX}:${port}${path}"
    
    if curl -s --max-time $TIMEOUT --fail-with-body -o /dev/null "$full_url" 2>/dev/null; then
        log_success "HTTP ${hostname} (${full_url}) - OK"
        return 0
    else
        local status_code=$(curl -s --max-time $TIMEOUT -w "%{http_code}" -o /dev/null "$full_url" 2>/dev/null || echo "000")
        log_error "HTTP ${hostname} (${full_url}) - Failed (HTTP ${status_code})"
        return 1
    fi
}

# Test TCP connection
test_tcp_connection() {
    local hostname="$1"
    local port="$2"
    
    local full_host="${hostname}${DOMAIN_SUFFIX}"
    
    if timeout $TIMEOUT bash -c "</dev/tcp/${full_host}/${port}" 2>/dev/null; then
        log_success "TCP ${hostname}:${port} - OK"
        return 0
    else
        log_error "TCP ${hostname}:${port} - Failed"
        return 1
    fi
}

# Test connection async (background job)
test_connection_async() {
    local hostname="$1"
    local port="$2"
    local path="${3:-/}"
    local protocol="${4:-http}"
    
    if [[ "$protocol" == "tcp" ]]; then
        test_tcp_connection "$hostname" "$port"
    else
        test_http_connection "$hostname" "$port" "$path" "$protocol"
    fi
}

# Parse config file and test connections by category (async)
test_category() {
    local category="$1"
    
    log_info "Testing ${category} hosts..."
    
    local total=0
    local pids=()
    local results=()
    
    # Read config file and filter by category, start background jobs
    while IFS='|' read -r hostname port path protocol cat description; do
        # Skip comments and empty lines
        [[ "$hostname" =~ ^#.*$ ]] && continue
        [[ -z "$hostname" ]] && continue
        
        # Filter by category (case insensitive)
        if [[ "$(echo "$cat" | tr '[:upper:]' '[:lower:]')" == "$(echo "$category" | tr '[:upper:]' '[:lower:]')" ]]; then
            total=$((total + 1))
            
            # Start background job and capture PID
            test_connection_async "$hostname" "$port" "$path" "$protocol" &
            pids+=($!)
        fi
    done < "$HOSTS_FILE"
    
    # Wait for all background jobs to complete and count successes
    local passed=0
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            passed=$((passed + 1))
        fi
    done
    
    if [[ $total -gt 0 ]]; then
        log_info "Category ${category}: ${passed}/${total} tests passed"
        echo
    else
        log_warning "No hosts found for category: ${category}"
    fi
}

# Test all hosts in config file (async)
test_all_hosts() {
    log_info "Testing all configured hosts..."
    
    local total=0
    local pids=()
    
    # Start all tests in background
    while IFS='|' read -r hostname port path protocol cat description; do
        # Skip comments and empty lines
        [[ "$hostname" =~ ^#.*$ ]] && continue
        [[ -z "$hostname" ]] && continue
        
        total=$((total + 1))
        
        # Start background job
        test_connection_async "$hostname" "$port" "$path" "$protocol" &
        pids+=($!)
    done < "$HOSTS_FILE"
    
    # Wait for all jobs and count successes
    local passed=0
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            passed=$((passed + 1))
        fi
    done
    
    log_info "Total: ${passed}/${total} tests passed"
    echo
}

# List all configured hosts
list_hosts() {
    log_info "Configured Tailscale hosts:"
    echo
    
    printf "%-30s %-6s %-15s %-8s %-12s %s\n" "HOSTNAME" "PORT" "PROTOCOL" "CATEGORY" "STATUS" "DESCRIPTION"
    printf "%-30s %-6s %-15s %-8s %-12s %s\n" "$(printf '%*s' 30 '' | tr ' ' '-')" "$(printf '%*s' 6 '' | tr ' ' '-')" "$(printf '%*s' 15 '' | tr ' ' '-')" "$(printf '%*s' 8 '' | tr ' ' '-')" "$(printf '%*s' 12 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')"
    
    while IFS='|' read -r hostname port path protocol cat description; do
        # Skip comments and empty lines
        [[ "$hostname" =~ ^#.*$ ]] && continue
        [[ -z "$hostname" ]] && continue
        
        # Check if host is online (simple check)
        local status="unknown"
        if tailscale status 2>/dev/null | grep -q "^[0-9.]\\+\\s\\+${hostname}\\s"; then
            status="online"
        else
            status="offline"
        fi
        
        printf "%-30s %-6s %-15s %-8s %-12s %s\n" "$hostname" "$port" "$protocol" "$cat" "$status" "$description"
    done < "$HOSTS_FILE"
    
    echo
}

# Main function
main() {
    log_info "Starting Tailscale connectivity tests..."
    log_info "Domain suffix: ${DOMAIN_SUFFIX}"
    log_info "Timeout: ${TIMEOUT}s"
    echo
    
    if [[ ! -f "$HOSTS_FILE" ]]; then
        log_error "Hosts file not found: $HOSTS_FILE"
        exit 1
    fi
    
    # Check if we're connected to Tailscale
    if ! command -v tailscale >/dev/null 2>&1; then
        log_warning "tailscale command not found, cannot verify connection status"
    else
        if ! tailscale status >/dev/null 2>&1; then
            log_error "Not connected to Tailscale network"
            exit 1
        fi
        log_info "Connected to Tailscale network"
    fi
    
    echo
    
    # Test all hosts from config file
    test_all_hosts
    
    log_info "Testing completed!"
}

# Handle command line arguments
case "${1:-all}" in
    "monitoring")
        test_category "monitoring"
        ;;
    "data")
        test_category "data"
        ;;
    "solutions")
        test_category "solutions"
        ;;
    "list")
        list_hosts
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [OPTION]"
        echo "Test Tailscale connectivity to configured hosts"
        echo ""
        echo "Options:"
        echo "  all         Test all configured hosts (default)"
        echo "  monitoring  Test only monitoring services"
        echo "  data        Test only data services"
        echo "  solutions   Test only solutions services"
        echo "  list        List all configured hosts with status"
        echo "  help        Show this help message"
        echo ""
        echo "Configuration file: $HOSTS_FILE"
        ;;
    "all"|*)
        main
        ;;
esac