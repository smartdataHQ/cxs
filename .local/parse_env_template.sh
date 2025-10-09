#!/usr/bin/env bash
# Parser for structured .env.example.sensitive file
# Extracts prompt metadata from comments

parse_env_template() {
  local template_file="$1"
  local output_format="${2:-bash}"  # bash or json

  if [ ! -f "$template_file" ]; then
    echo "Error: Template file not found: $template_file" >&2
    return 1
  fi

  local current_step=""
  local in_group=""

  # Read entire file into array for lookahead
  local -a lines
  while IFS= read -r line_data; do
    lines+=("$line_data")
  done < "$template_file"

  local i=0
  while [ $i -lt ${#lines[@]} ]; do
    local line="${lines[$i]}"

    # Check for step headers (# Step N: Description)
    if [[ "$line" =~ ^#[[:space:]]*Step[[:space:]]+([0-9]+):[[:space:]]*(.+)$ ]]; then
      current_step="${BASH_REMATCH[1]}"
      in_group="${BASH_REMATCH[2]}"
      ((i++))
      continue
    fi

    # Check for @prompt directive
    if [[ "$line" =~ ^#[[:space:]]*@prompt:(.+)$ ]]; then
      local directive="${BASH_REMATCH[1]}"

      # Parse directive: step|required|type|description|default
      IFS='|' read -r step required type description default <<< "$directive"

      # Look ahead for @depends directive
      local depends=""
      local j=$((i + 1))
      while [ $j -lt ${#lines[@]} ]; do
        local next_line="${lines[$j]}"

        # Check for @depends
        if [[ "$next_line" =~ ^#[[:space:]]*@depends:(.+)$ ]]; then
          # Replace pipe with colon to avoid field splitting issues
          depends="${BASH_REMATCH[1]}"
          depends="${depends//|/:}"
          ((j++))
          continue
        fi

        # Found variable name
        if [[ "$next_line" =~ ^([A-Z_]+)= ]]; then
          local var_name="${BASH_REMATCH[1]}"

          # Use current_step if step is "auto"
          if [ "$step" = "auto" ]; then
            step="$current_step"
          fi

          # Output in requested format
          if [ "$output_format" = "json" ]; then
            echo "{\"var\":\"$var_name\",\"step\":\"$step\",\"required\":$required,\"type\":\"$type\",\"desc\":\"$description\",\"default\":\"$default\",\"depends\":\"$depends\"}"
          else
            # Bash array format: var|step|required|type|description|default|depends
            echo "$var_name|$step|$required|$type|$description|$default|$depends"
          fi
          break
        fi
        ((j++))
      done
    fi
    ((i++))
  done
}

# Example usage:
# parse_env_template ".env.example.sensitive" "bash"
# Output: DOCKER_PAT|1|true|text|Docker Personal Access Token|

# For script integration:
# while IFS='|' read -r var step required type desc default; do
#   prompt_secret_from_metadata "$var" "$step" "$required" "$type" "$desc" "$default"
# done < <(parse_env_template ".env.example.sensitive")

prompt_secret_from_metadata() {
  local var_name="$1"
  local step="$2"
  local required="$3"
  local type="$4"
  local description="$5"
  local default="$6"

  # Convert type to default value
  case "$type" in
    auto-generate-16)
      default="AUTO_GENERATE:16"
      ;;
    auto-generate-24)
      default="AUTO_GENERATE:24"
      ;;
    auto-generate-32)
      default="AUTO_GENERATE:32"
      ;;
    auto-generate-44)
      default="AUTO_GENERATE:32"  # Generate 32, will be 44 base64
      ;;
  esac

  # Convert required string to boolean
  local is_required="false"
  if [ "$required" = "true" ]; then
    is_required="true"
  fi

  echo "Prompting for: $var_name (Step $step, Required: $is_required)"
  echo "  Description: $description"
  echo "  Type: $type"
  echo "  Default: $default"
  echo
}

# Demo
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "=== Parsing .env.example.sensitive ==="
  echo
  parse_env_template ".env.example.sensitive" "bash" | while IFS='|' read -r var step required type desc default; do
    prompt_secret_from_metadata "$var" "$step" "$required" "$type" "$desc" "$default"
  done
fi