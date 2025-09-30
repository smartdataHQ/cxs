#!/usr/bin/env bash
set -euo pipefail

GITHUB_OWNER="${GITHUB_OWNER:-smartdataHQ}"
GITHUB_REPO="${GITHUB_REPO:-cxs}"
GITHUB_PATH=".local"
DEFAULT_GITHUB_REF="${DEFAULT_GITHUB_REF:-main}"
DEFAULT_TARGET_DIR="mimir-onprem"

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Fetch the .local stack from GitHub and run docker compose.

Options:
  -t, --target <dir>     Target directory for the stack (default: mimir-onprem)
  -e, --env-file <file1,file2,...>  Comma-separated paths to environment files (non-sensitive first, sensitive last; overrides apply in order)
      --no-up            Download only; do not run docker compose up
      --no-interactive   Skip interactive secret prompts (use existing files)
      --ref <git-ref>    Git ref (branch/tag/SHA) to fetch (defaults to env GITHUB_REF or main)
  -h, --help             Show this help text
USAGE
}

resolve_abs_path() {
  local path="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$path" <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
    return 0
  fi
  if [ -d "$path" ]; then
    (cd "$path" && pwd)
  else
    local dir
    dir="$(dirname "$path")"
    local base
    base="$(basename "$path")"
    (cd "$dir" >/dev/null 2>&1 && printf '%s/%s\n' "$(pwd)" "$base") || return 1
  fi
}

read_env_value() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
key = sys.argv[2]
value = ""
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith('#') or '=' not in line:
        continue
    k, v = line.split('=', 1)
    if k.strip() == key:
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        value = v
        break
print(value, end="")
PY
  else
    local line
    line=$(grep -E "^${key}=" "$file" | tail -n1 || true)
    line="${line#${key}=}"
    line="${line%%$'\r'}"
    if [[ "${line}" =~ ^".*"$ ]] || [[ "${line}" =~ ^'.*'$ ]]; then
      line="${line:1:${#line}-2}"
    fi
    printf '%s' "$line"
  fi
}

# Download example env file from GitHub if missing
download_example() {
  local example_name="$1"
  local target_example="$2"
  if [ ! -f "$target_example" ]; then
    echo "Downloading $example_name from GitHub..."
    curl -s -L "https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPO}/${DEFAULT_GITHUB_REF}/${GITHUB_PATH}/${example_name}" -o "$target_example"
    if [ $? -ne 0 ]; then
      echo "Failed to download $example_name. Check internet or GITHUB_REF." >&2
      exit 1
    fi
  fi
}

# Generate random password/key
generate_random() {
  local length="${1:-16}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 "$length" | tr -d '\n'
  else
    # Fallback using /dev/urandom
    head -c "$length" /dev/urandom | base64 | tr -d '\n'
  fi
}

# Prompt for a secret with description and optional default
prompt_secret() {
  local var_name="$1"
  local description="$2"
  local default_value="$3"
  local is_required="$4"
  local value=""
  
  echo
  echo "📋 $var_name: $description"
  if [ -n "$default_value" ]; then
    if [[ "$default_value" == "AUTO_GENERATE"* ]]; then
      local gen_length="${default_value#AUTO_GENERATE:}"
      gen_length="${gen_length:-16}"
      default_value=$(generate_random "$gen_length")
      echo "   Auto-generated: $default_value"
    fi
    echo "   Default: $default_value"
  fi
  
  if [ "$is_required" = "true" ]; then
    echo "   (REQUIRED)"
  else
    echo "   (OPTIONAL - press Enter to skip)"
  fi
  
  printf "   Enter value: "
  read -r value
  
  if [ -z "$value" ]; then
    if [ -n "$default_value" ]; then
      value="$default_value"
    elif [ "$is_required" = "true" ]; then
      echo "   ❌ This field is required. Please enter a value."
      prompt_secret "$var_name" "$description" "$default_value" "$is_required"
      return
    fi
  fi
  
  # Validate based on var type
  case "$var_name" in
    DOCKER_PAT)
      if [[ ! "$value" =~ ^(ghp_|dckr_) ]] && [ -n "$value" ]; then
        echo "   ⚠️  Warning: Docker PAT should start with 'ghp_' or 'dckr_'"
      fi
      ;;
    *_PASSWORD)
      if [ ${#value} -lt 8 ] && [ -n "$value" ]; then
        echo "   ⚠️  Warning: Password should be at least 8 characters"
      fi
      ;;
    OPENAI_API_KEY)
      if [[ ! "$value" =~ ^sk- ]] && [ -n "$value" ]; then
        echo "   ⚠️  Warning: OpenAI API key should start with 'sk-'"
      fi
      ;;
    FERNET_KEY_PATTERN)
      if [ -n "$value" ] && [ ${#value} -ne 44 ]; then
        echo "   ❌ Error: Fernet key must be exactly 44 base64 characters"
        echo "   Current length: ${#value}"
        echo "   Auto-generating a valid key..."
        value=$(generate_random 32)
        echo "   Generated: $value"
      fi
      ;;
  esac
  
  # Set global variable for caller to use
  PROMPT_VALUE="$value"
}

# Process prompts for a single step (helper function)
process_step_prompts() {
  local step_num="$1"
  local output_file="$2"
  shift 2
  local prompts=("$@")

  # Map step numbers to names
  local step_name
  case "$step_num" in
    1) step_name="Docker Authentication" ;;
    2) step_name="Database Passwords" ;;
    3) step_name="AI/ML Service Keys" ;;
    4) step_name="Application Security Keys" ;;
    5) step_name="Optional API Keys (press Enter to skip)" ;;
    6) step_name="On-Prem Configuration (Required)" ;;
    7) step_name="SFTP Integration (Optional - press Enter to skip)" ;;
    8) step_name="Single Sign-On (Optional - press Enter to skip)" ;;
  esac

  echo "Step $step_num/8: $step_name"

  # Track special values for dependency handling
  declare -A STEP_VALUES

  for prompt_data in "${prompts[@]}"; do
    IFS='|' read -r var required type desc default depends <<< "$prompt_data"

    # Check dependencies
    if [ -n "$depends" ]; then
      IFS='|' read -r dep_var dep_condition <<< "$depends"

      case "$dep_condition" in
        not-empty)
          # Skip if dependency variable is empty
          if [ -z "${STEP_VALUES[$dep_var]}" ]; then
            continue
          fi
          ;;
        always)
          # Always process (dependency just for documentation)
          ;;
      esac
    fi

    # Convert type to default
    case "$type" in
      auto-generate-16) default="AUTO_GENERATE:16" ;;
      auto-generate-24) default="AUTO_GENERATE:24" ;;
      auto-generate-32) default="AUTO_GENERATE:32" ;;
      auto-generate-44) default="AUTO_GENERATE:32" ;;
    esac

    # Handle variable substitution in defaults
    if [[ "$default" =~ ^\$\{([A-Z_]+)\}$ ]]; then
      local ref_var="${BASH_REMATCH[1]}"
      default="${STEP_VALUES[$ref_var]:-}"
    fi

    # Prompt using existing function
    prompt_secret "$var" "$desc" "$default" "$required"

    # Store value for potential reference by other vars
    STEP_VALUES["$var"]="$PROMPT_VALUE"

    # Write to file if value provided
    if [ -n "$PROMPT_VALUE" ]; then
      echo "$var=\"$PROMPT_VALUE\"" >> "$output_file"
    fi
  done
}

# Interactive setup for all customer secrets
prompt_for_secrets() {
  local sensitive_file="$1"
  local template_file="$SCRIPT_DIR/.env.example.sensitive"

  echo
  echo "🔐 MimIR Setup: Customer Secrets Configuration"
  echo "================================================"
  echo "We'll walk through each required secret. You can:"
  echo "• Press Enter to use auto-generated values (for passwords)"
  echo "• Enter your own values (for API keys provided to you)"
  echo "• Press Enter to skip optional items"
  echo

  # Start building the env file
  cat > "$sensitive_file" <<EOF
# .env.sensitive: Customer Secrets (Auto-generated by installer)
# Do NOT commit this file. Generated on $(date)

EOF

  # Source the template parser
  source "$SCRIPT_DIR/parse_env_template.sh"

  # Group prompts by step
  local current_step=""
  local step_prompts=()

  # Parse template and group by step
  while IFS='|' read -r var step required type desc default depends; do
    if [ "$step" != "$current_step" ]; then
      # Process previous step if any
      if [ -n "$current_step" ] && [ ${#step_prompts[@]} -gt 0 ]; then
        process_step_prompts "$current_step" "$sensitive_file" "${step_prompts[@]}"
        step_prompts=()
      fi
      current_step="$step"
    fi

    step_prompts+=("$var|$required|$type|$desc|$default|$depends")
  done < <(parse_env_template "$template_file")

  # Process final step
  if [ ${#step_prompts[@]} -gt 0 ]; then
    process_step_prompts "$current_step" "$sensitive_file" "${step_prompts[@]}"
  fi

  # Add fixed values
  cat >> "$sensitive_file" <<'EOF'

# Fixed values (do not change)
DOCKER_REGISTRY="docker.io"
DOCKER_USERNAME="quicklookup"
CLICKHOUSE_USER="default"
REDIS_DB=0
EOF

  echo
  echo "✅ Secrets configuration complete! Saved to $sensitive_file"
  echo

  # TLS Configuration Guidance
  echo "🔒 TLS/SSL Configuration (Optional)"
  echo "═══════════════════════════════════════════════"
  echo "By default, MimIR runs on HTTP (http://localhost)."
  echo "For production deployments, enable HTTPS:"
  echo
  echo "1. Generate or obtain TLS certificates:"
  echo "   # Self-signed (for testing):"
  echo "   mkdir -p certs"
  echo "   openssl req -x509 -newkey rsa:2048 -nodes \\"
  echo "     -keyout certs/privkey.pem \\"
  echo "     -out certs/fullchain.pem \\"
  echo "     -days 365 -subj \"/CN=your-domain.com\""
  echo
  echo "2. Edit \$target_dir/.env.non-sensitive:"
  echo "   TLS_ENABLED=\"true\""
  echo "   PUBLIC_BASE_URL=\"https://your-domain.com\""
  echo "   TLS_CERTS_DIR=\"./certs\""
  echo
  echo "3. Restart containers:"
  echo "   docker compose down && docker compose up -d"
  echo
}


# Setup env files with interactive prompts (smoothest experience)
setup_env_files() {
  local target_dir="$1"
  # Create env files in target directory for better organization
  mkdir -p "$target_dir"
  local target_abs="$(cd "$target_dir" && pwd)"
  local non_sensitive="$target_abs/.env.non-sensitive"
  local sensitive="$target_abs/.env.sensitive"
  local example_non="$target_abs/.env.example.non-sensitive"
  local example_sensitive="$target_abs/.env.example.sensitive"
  
  # Download non-sensitive example and copy (ready with defaults)
  download_example ".env.example.non-sensitive" "$example_non"
  if [ ! -f "$non_sensitive" ]; then
    cp "$example_non" "$non_sensitive"
    echo "✅ Created $non_sensitive with safe defaults."
  fi
  
  # For sensitive: Interactive prompts instead of editor
  if [ ! -f "$sensitive" ] && [ "$NON_INTERACTIVE" != "true" ]; then
    prompt_for_secrets "$sensitive"
  elif [ ! -f "$sensitive" ]; then
    echo "Run without --no-interactive for guided setup, or create $sensitive manually." >&2
    exit 1
  else
    echo "✅ Using existing $sensitive"
  fi

  # Set ENV_FILES_ABS to these target directory files (absolute for compose)
  ENV_FILES_ABS=()
  ENV_FILES_ABS+=("$non_sensitive")
  ENV_FILES_ABS+=("$sensitive")
  ENV_FILES_FOR_AUTH=("${ENV_FILES_ABS[@]}")
}

TARGET_DIR="$DEFAULT_TARGET_DIR"
ENV_FILES_INPUT=""
RUN_COMPOSE=true
NON_INTERACTIVE=false
CLI_GITHUB_REF=""
ENV_FILES_ABS=()
ENV_FILES_FOR_AUTH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    -e|--env-file)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      ENV_FILES_INPUT="$2"
      shift 2
      ;;
    --no-up)
      RUN_COMPOSE=false
      shift
      ;;
    --no-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --ref)
      [[ $# -lt 2 ]] && { echo "Missing value for $1" >&2; exit 1; }
      CLI_GITHUB_REF="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$ENV_FILES_INPUT" ]]; then
  IFS=',' read -ra temp_files <<< "$ENV_FILES_INPUT"
  for file in "${temp_files[@]}"; do
    local abs_file
    abs_file="$(resolve_abs_path "$file")"
    if [ -n "$abs_file" ] && [ -f "$abs_file" ]; then
      ENV_FILES_ABS+=("$abs_file")
    else
      echo "Environment file not found or invalid: $file" >&2
      exit 1
    fi
  done
  ENV_FILES_FOR_AUTH=("${ENV_FILES_ABS[@]}")
else
  # Frictionless: Auto-setup env files in cwd if not provided
  setup_env_files "$TARGET_DIR"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "tar is required" >&2
  exit 1
fi

# Read from env files in order, last overrides
GITHUB_TOKEN_VALUE="${GITHUB_TOKEN:-}"
GITHUB_REF="${CLI_GITHUB_REF:-${GITHUB_REF:-$DEFAULT_GITHUB_REF}}"
for env_file in "${ENV_FILES_ABS[@]}"; do
  token_val=$(read_env_value "$env_file" "GITHUB_TOKEN")
  if [ -n "$token_val" ]; then
    GITHUB_TOKEN_VALUE="$token_val"
  fi
  ref_val=$(read_env_value "$env_file" "GITHUB_REF")
  if [ -n "$ref_val" ]; then
    GITHUB_REF="$ref_val"
  fi
done

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

DOWNLOAD_DIR="$TMP_DIR/download"
mkdir -p "$DOWNLOAD_DIR"

export OWNER="$GITHUB_OWNER"
export REPO="$GITHUB_REPO"
export GH_PATH="$GITHUB_PATH"
export DEST="$DOWNLOAD_DIR"
export GH_REF="$GITHUB_REF"
export GITHUB_TOKEN_DOWNLOAD="$GITHUB_TOKEN_VALUE"

python3 - <<'PY'
import json
import os
import sys
from pathlib import Path
from urllib import request, error

owner = os.environ['OWNER']
repo = os.environ['REPO']
path = os.environ['GH_PATH']
dest = Path(os.environ['DEST'])
ref = os.environ.get('GH_REF', '')
token = os.environ.get('GITHUB_TOKEN_DOWNLOAD', '')

base_url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path.strip('/')}"
if ref:
    root_url = f"{base_url}?ref={ref}"
else:
    root_url = base_url

def github_request(url: str, accept: str | None = None) -> bytes:
    headers = {'User-Agent': 'cxs-installer', 'Accept': accept or 'application/vnd.github.v3+json'}
    if token:
        headers['Authorization'] = f'token {token}'
    req = request.Request(url, headers=headers)
    try:
        with request.urlopen(req) as resp:
            return resp.read()
    except error.HTTPError as exc:
        message = exc.read().decode('utf-8', errors='ignore')
        raise SystemExit(f"GitHub request failed ({exc.code}): {url} - {message}") from exc

def ensure_list(data):
    if isinstance(data, list):
        return data
    return [data]

def save_file(item, target: Path) -> None:
    data = github_request(item['url'], accept='application/vnd.github.v3.raw')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)

def process(url: str, target_dir: Path) -> None:
    payload = github_request(url)
    data = json.loads(payload.decode('utf-8'))
    items = ensure_list(data)
    target_dir.mkdir(parents=True, exist_ok=True)
    for entry in items:
        entry_type = entry.get('type')
        name = entry.get('name')
        if not name:
            continue
        target_path = target_dir / name
        if entry_type == 'file' or entry_type == 'symlink':
            save_file(entry, target_path)
        elif entry_type == 'dir':
            process(entry['url'], target_path)
        else:
            # Skip unsupported types (e.g., submodule)
            continue

process(root_url, dest)
PY

STACK_SOURCE="$DOWNLOAD_DIR"
mkdir -p "$TARGET_DIR"
TARGET_DIR_ABS="$(cd "$TARGET_DIR" && pwd)"

echo "Preparing target directory at $TARGET_DIR_ABS"

# Copy all files directly to target root (flatter structure)
tar -C "$STACK_SOURCE" -cf - . | tar -C "$TARGET_DIR_ABS" -xf -

echo "Stack files ready in $TARGET_DIR_ABS"

STACK_TARGET="$TARGET_DIR_ABS"

if [ "$RUN_COMPOSE" = false ]; then
  echo "Skipping docker compose up."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker CLI is required but not found. Please install Docker Desktop from https://docker.com" >&2
  exit 1
fi

# Check if Docker daemon is running
echo "🔍 Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker daemon is not running. Please start Docker Desktop and try again." >&2
  echo "   On macOS: Open Docker Desktop app from Applications" >&2
  echo "   On Linux: Run 'sudo systemctl start docker'" >&2
  echo "   Test with: docker run hello-world" >&2
  exit 1
fi
echo "✅ Docker daemon is running"

# Check available disk space
echo "🔍 Checking disk space..."
if command -v df >/dev/null 2>&1; then
  if df -BG "$TARGET_DIR_ABS" >/dev/null 2>&1; then
    available_gb=$(df -BG "$TARGET_DIR_ABS" | awk 'NR==2 {print $4}' | sed 's/G//')
  elif df -k "$TARGET_DIR_ABS" >/dev/null 2>&1; then
    # macOS doesn't support -BG, use -k and convert
    available_kb=$(df -k "$TARGET_DIR_ABS" | awk 'NR==2 {print $4}')
    available_gb=$((available_kb / 1024 / 1024))
  fi

  if [ -n "$available_gb" ] && [ "$available_gb" -lt 30 ]; then
    echo "⚠️  Warning: Only ${available_gb}GB disk space available." >&2
    echo "   Recommended: 50GB+ for AI models and data storage." >&2
    echo "   Required space breakdown:" >&2
    echo "     - Docker images: ~8GB" >&2
    echo "     - AI models (HuggingFace): ~10GB" >&2
    echo "     - Database storage: ~5-50GB (usage-dependent)" >&2
    printf "   Continue anyway? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Installation cancelled. Please free up disk space and try again." >&2
      exit 1
    fi
  else
    echo "✅ Sufficient disk space available (${available_gb}GB+)"
  fi
fi

# Test Docker functionality
echo "🔍 Testing Docker functionality..."
if ! docker run --rm hello-world >/dev/null 2>&1; then
  echo "❌ Docker test failed. Please check Docker installation and permissions." >&2
  echo "   Try running: docker run hello-world" >&2
  echo "   If it fails, restart Docker Desktop or check permissions." >&2
  exit 1
fi
echo "✅ Docker is working correctly"

# Check Docker memory allocation
echo "🔍 Checking Docker memory allocation..."
if docker_mem=$(docker info --format '{{.MemTotal}}' 2>/dev/null); then
  docker_mem_gb=$((docker_mem / 1073741824))
  if [ "$docker_mem_gb" -lt 12 ]; then
    echo "⚠️  Warning: Docker has only ${docker_mem_gb}GB RAM allocated." >&2
    echo "   Recommended: 16GB+ for AI services (embeddings, anonymization)." >&2
    echo "   Current requirements:" >&2
    echo "     - cxs-embeddings: 6-12GB" >&2
    echo "     - cxs-anonymization: 4-8GB" >&2
    echo "     - Other services: ~4GB" >&2
    echo "   Containers may crash with OOM (Out of Memory) errors." >&2
    echo "   To increase: Docker Desktop > Settings > Resources > Memory" >&2
    printf "   Continue anyway? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Installation cancelled. Please increase Docker memory and try again." >&2
      exit 1
    fi
  else
    echo "✅ Sufficient Docker memory allocated (${docker_mem_gb}GB+)"
  fi
else
  echo "⚠️  Could not determine Docker memory allocation. Proceeding..." >&2
fi

# Get last env file for auth/creds (bash 3.2 compatible)
if [ ${#ENV_FILES_FOR_AUTH[@]} -eq 0 ]; then
  echo "No environment files available. Run setup_env_files first." >&2
  exit 1
fi
last_env_index=$(( ${#ENV_FILES_FOR_AUTH[@]} - 1 ))
last_env="${ENV_FILES_FOR_AUTH[$last_env_index]}"

# Read Docker creds from last env file (sensitive)
DOCKER_REGISTRY=$(read_env_value "$last_env" "DOCKER_REGISTRY")
DOCKER_USERNAME=$(read_env_value "$last_env" "DOCKER_USERNAME")
DOCKER_PAT=$(read_env_value "$last_env" "DOCKER_PAT")
DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.io}

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PAT" ]; then
  echo "DOCKER_USERNAME and DOCKER_PAT must be set in the last env file ($last_env)" >&2
  echo "Current file contents:" >&2
  head -5 "$last_env" >&2 || echo "File not readable" >&2
  exit 1
fi

  # Validate key sensitive vars in last file before up (best practice - up to date with all critical)
CLICKHOUSE_PASSWORD=$(read_env_value "$last_env" "CLICKHOUSE_PASSWORD")
REDIS_PASSWORD=$(read_env_value "$last_env" "REDIS_PASSWORD")
OPENAI_API_KEY=$(read_env_value "$last_env" "OPENAI_API_KEY")
UNSTRUCTURED_API_KEY=$(read_env_value "$last_env" "UNSTRUCTURED_API_KEY")
SECRET_KEY=$(read_env_value "$last_env" "SECRET_KEY")
ONPREM_WRITE_KEY=$(read_env_value "$last_env" "ONPREM_WRITE_KEY")
ONPREM_ORGANIZATION=$(read_env_value "$last_env" "ONPREM_ORGANIZATION")
ONPREM_ORGANIZATION_GID=$(read_env_value "$last_env" "ONPREM_ORGANIZATION_GID")
ONPREM_PARTITION=$(read_env_value "$last_env" "ONPREM_PARTITION")

if [ -z "$CLICKHOUSE_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ] || [ -z "$OPENAI_API_KEY" ] || [ -z "$UNSTRUCTURED_API_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$ONPREM_WRITE_KEY" ] || [ -z "$ONPREM_ORGANIZATION" ] || [ -z "$ONPREM_ORGANIZATION_GID" ] || [ -z "$ONPREM_PARTITION" ]; then
  echo "Required secrets missing in last env file ($last_env): CLICKHOUSE_PASSWORD, REDIS_PASSWORD, OPENAI_API_KEY, UNSTRUCTURED_API_KEY, SECRET_KEY, ONPREM_WRITE_KEY, ONPREM_ORGANIZATION, ONPREM_ORGANIZATION_GID, ONPREM_PARTITION." >&2
  echo "Fill .env.sensitive and rerun." >&2
  exit 1
fi

echo "Logging into Docker registry $DOCKER_REGISTRY..."
if ! printf '%s' "$DOCKER_PAT" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin >/dev/null; then
  echo "Docker login failed" >&2
  exit 1
fi

COMPOSE_BIN=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN=(docker-compose)
  else
    echo "Docker Compose is not available" >&2
    exit 1
  fi
fi

COMPOSE_ARGS=()
# Use absolute paths for env files to avoid directory dependency issues
for env_file in "${ENV_FILES_ABS[@]}"; do
  COMPOSE_ARGS+=("--env-file" "$env_file")
done
COMPOSE_ARGS+=("-f" "docker-compose.mimir.onprem.yml" "up" "-d")

pushd "$STACK_TARGET" >/dev/null

echo "Running docker compose up from $STACK_TARGET..."
echo "Using env files:"
for env_file in "${ENV_FILES_ABS[@]}"; do
  echo "  - $env_file"
done
"${COMPOSE_BIN[@]}" "${COMPOSE_ARGS[@]}"

popd >/dev/null

echo
echo "🎉 Installation complete!"
echo

# Post-install health check
echo "⏳ Waiting for services to start (this may take 5-10 minutes for AI model downloads)..."
sleep 30

pushd "$STACK_TARGET" >/dev/null
echo "Checking service status..."
healthy=0
unhealthy=0
starting=0

# Count service health
while IFS= read -r line; do
  if echo "$line" | grep -q "(healthy)"; then
    ((healthy++))
  elif echo "$line" | grep -q "(unhealthy)"; then
    ((unhealthy++))
  elif echo "$line" | grep -q "(starting)"; then
    ((starting++))
  fi
done < <("${COMPOSE_BIN[@]}" ps 2>/dev/null || true)

echo
if [ "$healthy" -gt 0 ]; then
  echo "✅ $healthy services healthy"
fi
if [ "$starting" -gt 0 ]; then
  echo "⏳ $starting services still starting (check again in a few minutes)"
fi
if [ "$unhealthy" -gt 0 ]; then
  echo "⚠️  $unhealthy services unhealthy"
  echo "   Check logs: docker compose logs -f"
fi

popd >/dev/null

echo
echo "🌐 Access your MimIR setup at: http://localhost"
echo "📊 Check status: docker compose ps"
echo "📝 View logs: docker compose logs -f [service-name]"
echo "📂 Working directory: $STACK_TARGET"
echo
echo "⚠️  Note: First startup may take 5-10 minutes as AI models download (~10GB)"