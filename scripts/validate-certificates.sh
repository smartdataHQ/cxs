#!/bin/bash

# Certificate validation script
# Validates all ingresses for proper TLS configuration and cert-manager setup

# Don't exit on errors in validation functions - we want to continue checking all ingresses
set -o pipefail

# Check dependencies
check_dependencies() {
    local missing=()
    
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing[*]}${NC}" >&2
        exit 1
    fi
}

# Function to get yaml value (fallback if yq is not available)
get_yaml_value() {
    local yaml_content="$1"
    local path="$2"
    
    if command -v yq >/dev/null 2>&1; then
        echo "$yaml_content" | yq "$path" 2>/dev/null || echo "null"
    else
        # Simple fallback for common cases
        case "$path" in
            '.metadata.annotations["cert-manager.io/cluster-issuer"]')
                echo "$yaml_content" | grep -o 'cert-manager.io/cluster-issuer: [^"]*' | cut -d' ' -f2 | tr -d '"' || echo "null"
                ;;
            '.spec.tls | length')
                echo "$yaml_content" | grep -c '  secretName:' || echo "0"
                ;;
            *)
                echo "null"
                ;;
        esac
    fi
}

check_dependencies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_INGRESSES=0
VALID_INGRESSES=0
INVALID_INGRESSES=0
MISSING_CERTIFICATES=0

echo -e "${BLUE}🔍 Certificate Validation Report${NC}"
echo "================================================"

# Function to check if certificate exists and is ready
check_certificate() {
    local namespace=$1
    local cert_name=$2
    
    if kubectl get certificate "$cert_name" -n "$namespace" &>/dev/null; then
        local ready=$(kubectl get certificate "$cert_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "$ready" == "True" ]]; then
            echo -e "    ${GREEN}✓${NC} Certificate '$cert_name' is ready"
            return 0
        else
            echo -e "    ${RED}✗${NC} Certificate '$cert_name' exists but not ready"
            return 1
        fi
    else
        echo -e "    ${RED}✗${NC} Certificate '$cert_name' not found"
        ((MISSING_CERTIFICATES++))
        return 1
    fi
}

# Function to check if secret exists
check_secret() {
    local namespace=$1
    local secret_name=$2
    
    if kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo -e "    ${GREEN}✓${NC} TLS secret '$secret_name' exists"
        return 0
    else
        echo -e "    ${RED}✗${NC} TLS secret '$secret_name' not found"
        return 1
    fi
}

# Function to validate TLS certificate
validate_tls() {
    local host=$1
    local expected_issuer="Let's Encrypt"
    
    echo -e "    ${BLUE}🔒${NC} Testing TLS connection to $host..."
    
    # Test TLS connection and get certificate info
    if cert_info=$(echo | timeout 5 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -issuer -dates 2>/dev/null); then
        issuer=$(echo "$cert_info" | grep "issuer=" | sed 's/issuer=//')
        not_after=$(echo "$cert_info" | grep "notAfter=" | sed 's/notAfter=//')
        
        # Check if issued by Let's Encrypt
        if echo "$issuer" | grep -q "Let's Encrypt"; then
            echo -e "    ${GREEN}✓${NC} Certificate issued by Let's Encrypt"
            
            # Check expiration (warn if less than 30 days)
            if command -v date >/dev/null 2>&1; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS date command
                    exp_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null || echo 0)
                    now_epoch=$(date +%s)
                else
                    # Linux date command
                    exp_epoch=$(date -d "$not_after" +%s 2>/dev/null || echo 0)
                    now_epoch=$(date +%s)
                fi
                
                if [[ $exp_epoch -gt $now_epoch ]]; then
                    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
                    if [[ $days_left -lt 30 ]]; then
                        echo -e "    ${YELLOW}⚠${NC}  Certificate expires in $days_left days ($not_after)"
                    else
                        echo -e "    ${GREEN}✓${NC} Certificate expires in $days_left days"
                    fi
                else
                    echo -e "    ${RED}✗${NC} Certificate is expired ($not_after)"
                    return 1
                fi
            fi
            return 0
        else
            echo -e "    ${RED}✗${NC} Certificate not issued by Let's Encrypt"
            echo "      Issuer: $issuer"
            return 1
        fi
    else
        echo -e "    ${RED}✗${NC} Failed to connect to $host:443 or retrieve certificate"
        return 1
    fi
}

# Function to validate ingress
validate_ingress() {
    local namespace=$1
    local ingress_name=$2
    
    echo -e "\n${BLUE}📋 Validating ingress${NC}: $namespace/$ingress_name"
    ((TOTAL_INGRESSES++))
    
    local is_valid=true
    
    # Get ingress details
    local ingress_yaml=$(kubectl get ingress "$ingress_name" -n "$namespace" -o yaml 2>/dev/null)
    if [[ -z "$ingress_yaml" ]]; then
        echo -e "  ${RED}✗${NC} Ingress not found"
        ((INVALID_INGRESSES++))
        return 1
    fi
    
    # Check for cert-manager annotation
    local cert_issuer=$(get_yaml_value "$ingress_yaml" '.metadata.annotations["cert-manager.io/cluster-issuer"]')
    if [[ "$cert_issuer" == "letsencrypt-prod" ]]; then
        echo -e "  ${GREEN}✓${NC} Cert-manager annotation present: $cert_issuer"
    elif [[ "$cert_issuer" == "null" || -z "$cert_issuer" ]]; then
        echo -e "  ${YELLOW}⚠${NC}  No cert-manager annotation found"
        is_valid=false
    else
        echo -e "  ${RED}✗${NC} Unexpected cert-manager issuer: $cert_issuer"
        is_valid=false
    fi
    
    # Check TLS configuration using grep (more reliable)
    if echo "$ingress_yaml" | grep -q "spec:" && echo "$ingress_yaml" | grep -q "tls:"; then
        echo -e "  ${GREEN}✓${NC} TLS configuration found"
        
        # Extract TLS secrets and hosts using simple parsing
        local secrets=$(echo "$ingress_yaml" | grep "secretName:" | awk '{print $2}' | tr -d '"')
        local hosts=$(echo "$ingress_yaml" | grep -A 10 "tls:" | grep -E '^\s*-\s+[a-zA-Z]' | awk '{print $2}' | tr -d '"')
        
        for secret in $secrets; do
            if [[ -n "$secret" ]]; then
                echo -e "    ${BLUE}TLS Secret:${NC} $secret"
                
                # Check if secret exists
                check_secret "$namespace" "$secret" || is_valid=false
                
                # Try to find corresponding certificate
                if [[ "$secret" == *"-tls" ]]; then
                    cert_name=$(echo "$secret" | sed 's/-tls$/-cert/')
                    check_certificate "$namespace" "$cert_name" || is_valid=false
                else
                    echo -e "      ${YELLOW}⚠${NC}  Cannot determine certificate name from secret: $secret"
                fi
            fi
        done
        
        # Test TLS for each host
        for host in $hosts; do
            if [[ -n "$host" && "$host" =~ contextsuite\.com ]]; then
                validate_tls "$host" || is_valid=false
            fi
        done
    else
        echo -e "  ${RED}✗${NC} No TLS configuration found"
        is_valid=false
    fi
    
    # Final verdict for this ingress
    if $is_valid; then
        echo -e "  ${GREEN}✅ VALID${NC}"
        ((VALID_INGRESSES++))
    else
        echo -e "  ${RED}❌ INVALID${NC}"
        ((INVALID_INGRESSES++))
    fi
}

# Main execution
echo "Scanning for ingresses with contextsuite.com domains..."
echo

# Find all ingresses with contextsuite.com hosts

ingresses=()
while IFS= read -r line; do
    [[ -n "$line" ]] && ingresses+=("$line")
done < <(kubectl get ingresses --all-namespaces -o json | jq -r '.items[] | select(.spec.rules[]?.host | test("contextsuite\\.com")) | "\(.metadata.namespace)/\(.metadata.name)"')

# Debug: Show what we found
echo "Found ${#ingresses[@]} ingresses with contextsuite.com domains"
for ing in "${ingresses[@]}"; do
    echo "  - $ing"
done
echo

if [[ ${#ingresses[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No ingresses found with contextsuite.com domains${NC}"
    exit 0
fi

# Validate each ingress
for ingress in "${ingresses[@]}"; do
    namespace=$(echo "$ingress" | cut -d'/' -f1)
    name=$(echo "$ingress" | cut -d'/' -f2)
    # Use || true to prevent script exit on validation failures
    validate_ingress "$namespace" "$name" || true
done

# Summary
echo -e "\n${BLUE}📊 SUMMARY${NC}"
echo "================================================"
echo -e "Total ingresses scanned: ${BLUE}$TOTAL_INGRESSES${NC}"
echo -e "Valid ingresses: ${GREEN}$VALID_INGRESSES${NC}"
echo -e "Invalid ingresses: ${RED}$INVALID_INGRESSES${NC}"
echo -e "Missing certificates: ${RED}$MISSING_CERTIFICATES${NC}"

if [[ $INVALID_INGRESSES -eq 0 && $MISSING_CERTIFICATES -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All ingresses are properly configured!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some issues found that need attention${NC}"
    exit 1
fi