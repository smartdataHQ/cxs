# Production Overlay Validation Scripts

## Overview

This directory contains scripts to automate the validation of Kubernetes production overlays against the cluster state using `kubectl diff`.

## validate-production.sh

### Purpose

Validates that Kubernetes overlays match what's currently running on the cluster. This helps ensure configuration drift doesn't occur between your GitOps manifests and actual cluster state. Supports any overlay name, with production as the default.

### Usage

```bash
# Validate all production overlays (default)
./scripts/validate-production.sh

# Validate staging overlays
./scripts/validate-production.sh --overlay=staging

# Validate specific apps only
./scripts/validate-production.sh --apps=contextsuite,contextapi,ctxllm

# Validate staging overlays for specific apps
./scripts/validate-production.sh --overlay=staging --apps=contextsuite,contextapi

# Verbose mode with detailed diff output
./scripts/validate-production.sh --verbose

# Mark in-sync apps as completed (for progress tracking)
./scripts/validate-production.sh --mark-completed

# Continue validation even if diffs found (don't exit early)
./scripts/validate-production.sh --continue-on-diff

# Combined example for comprehensive validation
./scripts/validate-production.sh --verbose --mark-completed --continue-on-diff

# Save diffs to files for inspection with delta or other diff tools
./scripts/validate-production.sh --save-diffs --continue-on-diff

# Validate staging with diff saving
./scripts/validate-production.sh --overlay=staging --save-diffs --continue-on-diff

# Auto-open diff with delta (single app only)
./scripts/validate-production.sh --apps=contextapi --auto-open

# Auto-open diff with different viewer
./scripts/validate-production.sh --apps=contextapi --auto-open --viewer=less

# Auto-open staging overlay diff
./scripts/validate-production.sh --overlay=staging --apps=contextapi --auto-open
```

### Options

- `-v, --verbose`: Show detailed diff output for apps with drift
- `-a, --apps=APP1,APP2`: Check specific apps only (comma-separated)
- `-o, --overlay=NAME`: Overlay name to validate (default: production)
- `-m, --mark-completed`: Create completion markers for in-sync apps
- `-c, --continue-on-diff`: Continue validation even if diffs are found
- `-d, --save-diffs`: Save diff output to files for inspection with diff tools
- `--auto-open`: Automatically open diff with viewer (single app only)
- `--viewer=TOOL`: Diff viewer tool (default: delta)
- `-h, --help`: Show help message

### Exit Codes

- `0`: All apps in sync
- `1`: Configuration drift detected
- `2`: Validation errors occurred  
- `3`: No production overlays found

### Output Example

```
[INFO] Starting production overlay validation...
[INFO] Found 18 apps with production overlays
[INFO] Validating contextsuite...
[✅] contextsuite: IN SYNC
[INFO] Validating contextapi...
[❌] contextapi: DRIFT DETECTED
[INFO] Validating ctxllm...
[✅] ctxllm: IN SYNC

=========================================
           VALIDATION SUMMARY
=========================================
Total apps checked: 18
✅ In sync: 12
❌ Out of sync: 5
⚠️  Errors: 1
```

### Completion Tracking

When using `--mark-completed`, the script creates completion markers in `.validation-status-{overlay}/` for apps that are in sync. On subsequent runs, these apps will be skipped unless run in verbose mode.

To reset completion tracking:
```bash
# Reset production overlay tracking
rm -rf .validation-status-production/

# Reset staging overlay tracking  
rm -rf .validation-status-staging/

# Reset all overlay tracking
rm -rf .validation-status-*/
```

### Diff File Inspection

When using `--save-diffs`, drift files are saved to `.validation-diffs-{overlay}/` directory. You can inspect them with your preferred diff tool:

```bash
# Using delta (recommended) - production overlay
delta < .validation-diffs-production/contextapi.diff

# Using delta - staging overlay
delta < .validation-diffs-staging/contextapi.diff

# Using bat
bat .validation-diffs-production/contextapi.diff

# Using less with color
less -R .validation-diffs-staging/contextapi.diff

# Using your preferred editor
code .validation-diffs-production/contextapi.diff
```

The diff files contain standard unified diff format with clear labels:
- **CLUSTER**: What's currently running in the cluster
- **OVERLAY**: What your specified overlay would deploy

This makes it easy to understand which changes would be applied when you deploy.

### Auto-Open Diff Feature

The `--auto-open` option automatically opens the diff file with your preferred viewer when validating a single app with drift.

**Requirements:**
- Must validate exactly one app (use `--apps=single-app`)
- App must have configuration drift
- Viewer tool must be available

**Supported viewers:**
- `delta -s` (default) - Syntax-highlighted side-by-side diff
- `delta` - Syntax-highlighted unified diff
- `delta -s --syntax-theme=gruvbox-dark` - Custom theme and flags
- `bat` - Syntax-highlighted file viewer
- `less -R` - Standard pager with color support
- `code` / `code-insiders` - Visual Studio Code
- Any other command-line tool with flags

**Examples:**
```bash
# Quick validation and review for a single app
./scripts/validate-production.sh --apps=contextapi --auto-open

# Use delta with specific theme and options
./scripts/validate-production.sh --apps=contextapi --auto-open --viewer="delta -s --syntax-theme=gruvbox-dark"

# Use bat instead of delta
./scripts/validate-production.sh --apps=contextapi --auto-open --viewer=bat

# Use less with color support
./scripts/validate-production.sh --apps=contextapi --auto-open --viewer="less -R"

# Staging overlay with auto-open
./scripts/validate-production.sh --overlay=staging --apps=contextapi --auto-open
```

**Behavior:**
- ✅ **Single app with drift**: Opens diff automatically
- ⚠️  **Multiple apps**: Shows warning, suggests using `--apps=<single-app>`
- ℹ️  **No drift**: Shows "all apps in sync" message
- ❌ **Viewer not found**: Shows error with suggested alternatives

### Integration

#### CI/CD Pipeline
```yaml
- name: Validate Production Overlays
  run: |
    ./scripts/validate-production.sh --continue-on-diff
    if [ $? -eq 1 ]; then
      echo "::warning::Configuration drift detected in production overlays"
    fi

- name: Validate Staging Overlays  
  run: |
    ./scripts/validate-production.sh --overlay=staging --continue-on-diff
    if [ $? -eq 1 ]; then
      echo "::warning::Configuration drift detected in staging overlays"
    fi
```

#### Pre-deployment Check
```bash
# Before deploying changes to production
./scripts/validate-production.sh || echo "Please resolve drift before deployment"

# Before deploying changes to staging
./scripts/validate-production.sh --overlay=staging || echo "Please resolve staging drift"
```

#### Monitoring Script
```bash
# Cron job for continuous monitoring - production
0 */6 * * * cd /path/to/repo && ./scripts/validate-production.sh --continue-on-diff --mark-completed > /var/log/prod-overlay-validation.log 2>&1

# Cron job for continuous monitoring - staging  
15 */6 * * * cd /path/to/repo && ./scripts/validate-production.sh --overlay=staging --continue-on-diff --mark-completed > /var/log/staging-overlay-validation.log 2>&1
```

### Troubleshooting

#### Common Issues

1. **kubectl context**: Ensure you're connected to the right cluster
   ```bash
   kubectl config current-context
   ```

2. **Permission errors**: Ensure your kubectl has read access to the namespaces
   ```bash
   kubectl auth can-i get deployments --all-namespaces
   ```

3. **Kustomization errors**: Check if the overlay directory and kustomization.yaml exists and is valid
   ```bash
   # Check production overlay
   kubectl kustomize apps/contextsuite/overlays/production
   
   # Check staging overlay
   kubectl kustomize apps/contextsuite/overlays/staging
   ```

## Supported Apps

The script automatically discovers apps with the specified overlay. For example:

**Production overlays** (18 apps):
- contextsuite, contextapi, ctxllm
- formapi, formclient
- gpt-api, gpt-chat
- mimir-api, mimir-chat
- And 9 more apps with production overlays

**Staging overlays** (varies by app):
- Apps that have staging overlay directories will be discovered automatically

## Development

### Adding New Features

The script is modular and extensible. Key functions:

- `validate_app()`: Core validation logic
- `mark_completed()`: Completion tracking
- `log_*()`: Colored output functions

### Testing

Test with specific apps first:
```bash
# Test production overlay
./scripts/validate-production.sh --apps=contextsuite --verbose

# Test staging overlay  
./scripts/validate-production.sh --overlay=staging --apps=contextsuite --verbose
```

Then run full validation:
```bash
# Test all production overlays
./scripts/validate-production.sh --continue-on-diff

# Test all staging overlays
./scripts/validate-production.sh --overlay=staging --continue-on-diff
```