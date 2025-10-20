#!/bin/bash

# Script to validate configMapGenerator migrations against cluster state
# Usage: ./validate-configmap-migration.sh <app-name> [overlay]
# Example: ./validate-configmap-migration.sh contextsuite production

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to extract and sort configmap data
extract_configmap_data() {
    local input="$1"
    echo "$input" | grep -A1000 "^data:" | grep -E "^  [A-Z_]+" | sort
}

# Check arguments
if [ $# -lt 1 ]; then
    print_color $RED "Usage: $0 <app-name> [overlay]"
    print_color $YELLOW "Example: $0 contextsuite production"
    exit 1
fi

APP_NAME="$1"
OVERLAY="${2:-production}"
APP_PATH="apps/$APP_NAME"

print_color $BLUE "=== ConfigMap Migration Validation for $APP_NAME ($OVERLAY) ==="
echo

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    print_color $RED "Error: App directory $APP_PATH does not exist"
    exit 1
fi

# Check if overlay exists
if [ ! -d "$APP_PATH/overlays/$OVERLAY" ]; then
    print_color $RED "Error: Overlay directory $APP_PATH/overlays/$OVERLAY does not exist"
    exit 1
fi

# Find configmap name pattern
CONFIGMAP_PATTERN=""
if [ -f "$APP_PATH/base/kustomization.yaml" ]; then
    CONFIGMAP_PATTERN=$(grep -A5 "configMapGenerator:" "$APP_PATH/base/kustomization.yaml" | grep "name:" | head -1 | awk '{print $3}' || true)
fi

if [ -z "$CONFIGMAP_PATTERN" ]; then
    print_color $RED "Error: No configMapGenerator found in base kustomization.yaml"
    print_color $YELLOW "This app may not be migrated yet or uses a different pattern"
    exit 1
fi

print_color $BLUE "ConfigMap name pattern: $CONFIGMAP_PATTERN"
echo

# Get namespace from kustomization
NAMESPACE=""
if [ -f "$APP_PATH/base/kustomization.yaml" ]; then
    NAMESPACE=$(grep "^namespace:" "$APP_PATH/base/kustomization.yaml" | awk '{print $2}' || true)
fi

if [ -z "$NAMESPACE" ]; then
    print_color $YELLOW "Warning: No namespace found in base kustomization.yaml, trying overlay..."
    if [ -f "$APP_PATH/overlays/$OVERLAY/kustomization.yaml" ]; then
        NAMESPACE=$(grep "^namespace:" "$APP_PATH/overlays/$OVERLAY/kustomization.yaml" | awk '{print $2}' || true)
    fi
fi

if [ -z "$NAMESPACE" ]; then
    print_color $RED "Error: Could not determine namespace"
    exit 1
fi

print_color $BLUE "Namespace: $NAMESPACE"
echo

# Check if cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    print_color $RED "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Get current configmap from cluster (try both static and hash-suffixed names)
print_color $BLUE "Fetching current configmap from cluster..."
CLUSTER_CONFIGMAP=""
ACTUAL_CONFIGMAP_NAME=""

# First try the static name
if kubectl get configmap "$CONFIGMAP_PATTERN" -n "$NAMESPACE" >/dev/null 2>&1; then
    CLUSTER_CONFIGMAP=$(kubectl get configmap "$CONFIGMAP_PATTERN" -n "$NAMESPACE" -o yaml 2>/dev/null)
    ACTUAL_CONFIGMAP_NAME="$CONFIGMAP_PATTERN"
    print_color $YELLOW "Found static configmap (not yet migrated): $CONFIGMAP_PATTERN"
else
    # Try to find hash-suffixed version
    HASH_SUFFIXED=$(kubectl get configmaps -n "$NAMESPACE" --no-headers 2>/dev/null | grep "^$CONFIGMAP_PATTERN-" | head -1 | awk '{print $1}' || true)
    
    if [ -n "$HASH_SUFFIXED" ]; then
        CLUSTER_CONFIGMAP=$(kubectl get configmap "$HASH_SUFFIXED" -n "$NAMESPACE" -o yaml 2>/dev/null)
        ACTUAL_CONFIGMAP_NAME="$HASH_SUFFIXED"
        print_color $GREEN "Found hash-suffixed configmap (already migrated): $HASH_SUFFIXED"
    else
        print_color $RED "Error: No configmap matching '$CONFIGMAP_PATTERN' found in namespace '$NAMESPACE'"
        print_color $YELLOW "Available configmaps in $NAMESPACE:"
        kubectl get configmaps -n "$NAMESPACE" --no-headers | awk '{print "  " $1}'
        exit 1
    fi
fi

# Generate configmap from kustomization
print_color $BLUE "Generating configmap from kustomization..."
GENERATED_CONFIGMAP=""
if ! GENERATED_CONFIGMAP=$(kubectl kustomize "$APP_PATH/overlays/$OVERLAY" 2>/dev/null); then
    print_color $RED "Error: Failed to generate kustomization"
    exit 1
fi

# Extract configmap data sections
print_color $BLUE "Extracting and comparing configmap data..."
echo

CLUSTER_DATA=$(extract_configmap_data "$CLUSTER_CONFIGMAP")
GENERATED_DATA=$(extract_configmap_data "$GENERATED_CONFIGMAP")

# Create temp files for comparison
TEMP_CLUSTER=$(mktemp)
TEMP_GENERATED=$(mktemp)
echo "$CLUSTER_DATA" > "$TEMP_CLUSTER"
echo "$GENERATED_DATA" > "$TEMP_GENERATED"

# Compare the data
if diff -q "$TEMP_CLUSTER" "$TEMP_GENERATED" >/dev/null; then
    print_color $GREEN "✅ SUCCESS: Generated configmap data matches cluster exactly!"
    
    # Show summary stats
    CLUSTER_COUNT=$(echo "$CLUSTER_DATA" | wc -l | xargs)
    GENERATED_COUNT=$(echo "$GENERATED_DATA" | wc -l | xargs)
    
    print_color $GREEN "✅ Config entries: $CLUSTER_COUNT (cluster) = $GENERATED_COUNT (generated)"
    
    # Show generated configmap name with hash
    GENERATED_NAME=$(echo "$GENERATED_CONFIGMAP" | grep -E "name: $CONFIGMAP_PATTERN-" | head -1 | awk '{print $2}')
    if [ -n "$GENERATED_NAME" ]; then
        print_color $GREEN "✅ Generated configmap name: $GENERATED_NAME"
    fi
    
else
    print_color $RED "❌ FAILURE: Generated configmap data differs from cluster"
    echo
    print_color $YELLOW "Differences (< cluster, > generated):"
    diff "$TEMP_CLUSTER" "$TEMP_GENERATED" || true
    echo
    
    # Show counts
    CLUSTER_COUNT=$(echo "$CLUSTER_DATA" | wc -l | xargs)
    GENERATED_COUNT=$(echo "$GENERATED_DATA" | wc -l | xargs)
    print_color $YELLOW "Config entries: $CLUSTER_COUNT (cluster) vs $GENERATED_COUNT (generated)"
    
    # Show what's missing or extra
    if [ "$CLUSTER_COUNT" -gt "$GENERATED_COUNT" ]; then
        print_color $YELLOW "Missing from generated:"
        comm -23 "$TEMP_CLUSTER" "$TEMP_GENERATED" | sed 's/^/  /'
    fi
    
    if [ "$GENERATED_COUNT" -gt "$CLUSTER_COUNT" ]; then
        print_color $YELLOW "Extra in generated:"
        comm -13 "$TEMP_CLUSTER" "$TEMP_GENERATED" | sed 's/^/  /'
    fi
    
    # Clean up and exit with error
    rm -f "$TEMP_CLUSTER" "$TEMP_GENERATED"
    exit 1
fi

# Clean up temp files
rm -f "$TEMP_CLUSTER" "$TEMP_GENERATED"

echo
print_color $GREEN "Migration validation completed successfully! 🎉"