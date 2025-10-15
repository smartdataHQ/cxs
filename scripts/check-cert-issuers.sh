#!/bin/bash

# Simple certificate issuer checker
# Just gets FQDNs from ingresses and checks their certificate issuers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Certificate Issuer Report${NC}"
echo "================================================"

# Function to check certificate issuer
check_issuer() {
    local host=$1
    
    echo -n "  $host: "
    
    # Test TLS connection and get issuer
    if cert_info=$(echo | timeout 3 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null); then
        issuer=$(echo "$cert_info" | sed 's/issuer=//')
        
        # Check if issued by Let's Encrypt
        if echo "$issuer" | grep -q "Let's Encrypt"; then
            echo -e "${GREEN}Let's Encrypt${NC}"
        else
            # Extract just the organization name for cleaner output
            org=$(echo "$issuer" | sed -n 's/.*O=\([^,]*\).*/\1/p' | head -1)
            if [[ -n "$org" ]]; then
                echo -e "${RED}$org${NC}"
            else
                echo -e "${RED}Other issuer${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Connection failed${NC}"
    fi
}

# Get all FQDNs from ingresses
echo "Getting FQDNs from ingresses..."
fqdns=$(kubectl get ingresses --all-namespaces -o json | jq -r '.items[].spec.rules[]?.host' | grep 'contextsuite\.com' | sort -u)

echo -e "\nChecking certificate issuers for $(echo "$fqdns" | wc -l) domains:\n"

# Check each FQDN
for fqdn in $fqdns; do
    if [[ -n "$fqdn" ]]; then
        check_issuer "$fqdn"
    fi
done

echo -e "\n${BLUE}Legend:${NC}"
echo -e "  ${GREEN}Green = Let's Encrypt (cert-manager working)${NC}"
echo -e "  ${RED}Red = Other issuer (needs migration)${NC}"
echo -e "  ${YELLOW}Yellow = Connection failed${NC}"