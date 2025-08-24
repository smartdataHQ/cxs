#!/usr/bin/env bash

# Lightweight .env loader for dev scripts
# - Accepts KEY=VALUE lines; ignores comments and blank lines
# - Trims surrounding quotes for VALUE
# - Exports variables into current shell
# - Provides sane defaults for known keys if not set

set -euo pipefail

trim_whitespace() {
  local s="$1"
  # trim leading
  s="${s#${s%%[![:space:]]*}}"
  # trim trailing
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

strip_quotes() {
  local v="$1"
  if [ "${#v}" -ge 2 ]; then
    case "$v" in
      "\"*\"") v="${v:1:${#v}-2}" ;;
      "'*'") v="${v:1:${#v}-2}" ;;
    esac
  fi
  printf '%s' "$v"
}

is_true() {
  # Usage: if is_true VAR_NAME; then ...
  local name="$1"
  local val="${!name-}"
  if [ -z "${val}" ]; then
    return 1
  fi
  # lowercase safely (portable)
  val=$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')
  case "$val" in
    true|1|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

load_env() {
  # load_env [/absolute/path/to/.env]
  local env_file="${1:-.env}"

  parse_file() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ''|\#*) continue ;;
          *=*)
            local key="${line%%=*}"
            local val="${line#*=}"
            key=$(printf '%s' "$key" | tr -d '[:space:]')
            val=$(trim_whitespace "$val")
            val=$(strip_quotes "$val")
            export "$key=$val"
            ;;
          *) : ;;
        esac
      done < "$file_path"
    fi
  }

  # Load base .env first
  parse_file "$env_file"

  # Then load optional .env.local for developer overrides
  local env_dir
  env_dir="$(cd "$(dirname "$env_file")" && pwd)"
  local local_file="$env_dir/.env.local"
  parse_file "$local_file"

  # Global defaults (dev)
  : "${ENABLE_POSTGRES:=true}"
  : "${ENABLE_CLICKHOUSE:=false}"
  : "${ENABLE_NEO4J:=false}"
  : "${ENABLE_KAFKA:=false}"
  : "${ENABLE_SOLR:=false}"

  : "${ENABLE_CONTEXTAPI:=false}"
  : "${ENABLE_CXSSERVICES:=false}"
  : "${ENABLE_INBOX:=false}"

  : "${ENABLE_GRAFANA:=false}"
  : "${ENABLE_LOKI:=false}"
  : "${ENABLE_PROMETHEUS:=false}"

  : "${GLOBAL_ADMIN_PASSWORD:=devpassword}"
  : "${GLOBAL_APP_PASSWORD:=devpassword}"

  # Remote endpoints (optional) - when set, scripts should prefer remote over local deploys/tests
  : "${REMOTE_POSTGRES_HOST:=}"
  : "${REMOTE_POSTGRES_PORT:=5432}"
  : "${REMOTE_POSTGRES_USER:=postgres}"
  : "${REMOTE_POSTGRES_PASSWORD:=}"

  : "${REMOTE_KAFKA_BROKERS:=}"           # comma-separated host:port
  : "${REMOTE_CLICKHOUSE_HOST:=}"
  : "${REMOTE_CLICKHOUSE_PORT:=9000}"
  : "${REMOTE_NEO4J_URI:=}"               # bolt+s://host:7687
  : "${REMOTE_SOLR_HOST:=}"
  : "${REMOTE_SOLR_PORT:=8983}"
}


