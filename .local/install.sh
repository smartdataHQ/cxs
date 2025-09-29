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
      --no-interactive   Skip interactive env setup (use existing files)
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

# Parse comma-separated env files into array
parse_env_files() {
  local env_input="$1"
  IFS=',' read -ra ENV_FILES <<< "$env_input"
  local abs_files=()
  for file in "${ENV_FILES[@]}"; do
    local abs_file
    abs_file="$(resolve_abs_path "$file")"
    if [ -n "$abs_file" ] && [ -f "$abs_file" ]; then
      abs_files+=("$abs_file")
    else
      echo "Environment file not found or invalid: $file" >&2
      exit 1
    fi
  done
  printf '%s\n' "${abs_files[@]}"
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

# Setup env files interactively/frictionless (cross-platform compatible)
setup_env_files() {
  local target_dir="$1"
  local non_sensitive=".env.non-sensitive"
  local sensitive=".env.sensitive"
  local example_non="${GITHUB_PATH}/.env.example.non-sensitive"
  local example_sensitive="${GITHUB_PATH}/.env.example.sensitive"

  # Download examples if missing (frictionless)
  download_example "$example_non" "$non_sensitive"
  download_example "$example_sensitive" "$sensitive"

  # Auto-copy non-sensitive (ready with defaults)
  if [ ! -f "$non_sensitive" ]; then
    echo "Created $non_sensitive with defaults. Edit if needed (e.g., ports)."
  fi

  # For sensitive: Copy keys-only, prompt to edit if not interactive
  if [ ! -f "$sensitive" ]; then
    echo "Created $sensitive (keys-only template)."
    if [ "$NON_INTERACTIVE" != "true" ]; then
      # Open editor (prefer nano, fallback to vi; for Windows, user can use notepad externally)
      if command -v nano >/dev/null 2>&1; then
        nano "$sensitive"
      elif command -v vi >/dev/null 2>&1; then
        vi "$sensitive"
      else
        echo "No editor found (nano/vi). Edit $sensitive manually (fill secrets like DOCKER_PAT)."
        if command -v notepad >/dev/null 2>&1; then
          echo "On Windows, run 'notepad $sensitive' externally."
        fi
      fi
      echo "After editing $sensitive (fill secrets like DOCKER_PAT), press Enter to continue."
      read -r
    else
      echo "Run without --no-interactive, or fill $sensitive manually before rerun."
      exit 1
    fi
  fi

  # Set ENV_FILES_ABS to these local files (absolute for compose)
  ENV_FILES_ABS=()
  ENV_FILES_ABS+=("$(resolve_abs_path "$non_sensitive")")
  ENV_FILES_ABS+=("$(resolve_abs_path "$sensitive")")
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
  mapfile -t ENV_FILES_ABS < <(parse_env_files "$ENV_FILES_INPUT")
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
STACK_TARGET="$TARGET_DIR_ABS/.local"

echo "Preparing target directory at $STACK_TARGET"
rm -rf "$STACK_TARGET"
mkdir -p "$STACK_TARGET"

tar -C "$STACK_SOURCE" -cf - . | tar -C "$STACK_TARGET" -xf -

echo "Stack files ready in $STACK_TARGET"

# Best practice: If examples exist in stack, remind to copy/fill (but auto-setup already handled cwd)
if [ -f "$STACK_TARGET/.env.example.non-sensitive" ]; then
  echo "Examples available in $STACK_TARGET. Use --no-interactive if env files already set."
fi

if [ "$RUN_COMPOSE" = false ]; then
  echo "Skipping docker compose up."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI is required" >&2
  exit 1
fi

# Read Docker creds from last env file (sensitive)
DOCKER_REGISTRY=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "DOCKER_REGISTRY")
DOCKER_USERNAME=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "DOCKER_USERNAME")
DOCKER_PAT=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "DOCKER_PAT")
DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.io}

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PAT" ]; then
  echo "DOCKER_USERNAME and DOCKER_PAT must be set in the last env file (${ENV_FILES_FOR_AUTH[-1]})" >&2
  exit 1
fi

# Validate key sensitive vars in last file before up (best practice - up to date with all critical)
CLICKHOUSE_PASSWORD=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "CLICKHOUSE_PASSWORD")
REDIS_PASSWORD=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "REDIS_PASSWORD")
OPENAI_API_KEY=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "OPENAI_API_KEY")
VOYAGE_API_KEY=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "VOYAGE_API_KEY")
UNSTRUCTURED_API_KEY=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "UNSTRUCTURED_API_KEY")
SECRET_KEY=$(read_env_value "${ENV_FILES_FOR_AUTH[-1]}" "SECRET_KEY")

if [ -z "$CLICKHOUSE_PASSWORD" ] || [ -z "$REDIS_PASSWORD" ] || [ -z "$OPENAI_API_KEY" ] || [ -z "$VOYAGE_API_KEY" ] || [ -z "$UNSTRUCTURED_API_KEY" ] || [ -z "$SECRET_KEY" ]; then
  echo "Required secrets missing in last env file (${ENV_FILES_FOR_AUTH[-1]}): CLICKHOUSE_PASSWORD, REDIS_PASSWORD, OPENAI_API_KEY, VOYAGE_API_KEY, UNSTRUCTURED_API_KEY, SECRET_KEY." >&2
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
for env_file in "${ENV_FILES_ABS[@]}"; do
  COMPOSE_ARGS+=("--env-file" "$env_file")  # Absolute paths ensure compose finds them
done
COMPOSE_ARGS+=("-f" "docker-compose.mimir.onprem.yml" "up" "-d")

pushd "$STACK_TARGET" >/dev/null

echo "Running docker compose up..."
"${COMPOSE_BIN[@]}" "${COMPOSE_ARGS[@]}"

popd >/dev/null

echo "Installation complete. Verify with 'docker compose ps' from $STACK_TARGET."
