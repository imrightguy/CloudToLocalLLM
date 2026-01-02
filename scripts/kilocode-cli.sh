#!/bin/bash

# KiloCode CLI Wrapper - Bash Implementation
# Simplified configuration loading for Kilocode API.

set -euo pipefail

# Default values from environment
API_KEY="${KILOCODE_TOKEN:-}"
API_MODEL="${KILOCODE_MODEL:-x-ai/grok-code-fast-1}"
POSTHOG_API_KEY="${KILOCODE_POSTHOG_API_KEY:-}"
API_HOST="${KILOCODE_API_HOST:-api.kilocode.ai}"
API_PATH="${KILOCODE_API_PATH:-/v1/chat/completions}"
MAX_RETRIES="${KILOCODE_MAX_RETRIES:-3}"
RETRY_DELAY="${KILOCODE_RETRY_DELAY:-2}"

# Check if prompt is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <prompt>"
  exit 1
fi

PROMPT="$*"

# Check for required API key
if [ -z "$API_KEY" ]; then
  echo "Error: KILOCODE_TOKEN not found in environment."
  exit 1
fi

# Function to resolve environment variable references
resolve_env_ref() {
  local value="$1"
  if [[ $value =~ ^\$\{([A-Z0-9_]+)\}$ ]]; then
    env_var="${BASH_REMATCH[1]}"
    echo "${!env_var:-}"
  elif [[ $value =~ ^\$([A-Z0-9_]+)$ ]]; then
    env_var="${BASH_REMATCH[1]}"
    echo "${!env_var:-}"
  else
    echo "$value"
  fi
}

# Configuration loading logic - prioritize user config
CONFIG_PATHS=(
  "$HOME/.kilocode/config.json"
)

CONFIG_LOADED=false

for config_path in "${CONFIG_PATHS[@]}"; do
  if [ -f "$config_path" ]; then
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
      echo "Loading configuration from: $config_path"
    fi

    # Simple JSON parsing for providers array
    if command -v jq >/dev/null 2>&1; then
      if jq -e '.providers[0]' "$config_path" >/dev/null 2>&1; then
        resolved_token=$(jq -r '.providers[0].kilocodeToken // empty' "$config_path")
        resolved_model=$(jq -r '.providers[0].kilocodeModel // empty' "$config_path")
        resolved_posthog=$(jq -r '.providers[0].kilocodePosthogApiKey // empty' "$config_path")

        resolved_token=$(resolve_env_ref "$resolved_token")
        resolved_model=$(resolve_env_ref "$resolved_model")
        resolved_posthog=$(resolve_env_ref "$resolved_posthog")

        [ -n "$resolved_token" ] && API_KEY="$resolved_token"
        [ -n "$resolved_model" ] && API_MODEL="$resolved_model"
        [ -n "$resolved_posthog" ] && POSTHOG_API_KEY="$resolved_posthog"

        CONFIG_LOADED=true
        break
      fi
    else
      echo "Warning: jq not available, skipping config file parsing"
    fi
  fi
done

# Prepare JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "$API_MODEL",
  "messages": [
    {
      "role": "system",
      "content": "You are a CI/CD orchestration assistant. You analyze code changes and decide on version bumps and deployment strategies. Respond ONLY with valid JSON."
    },
    {
      "role": "user",
      "content": "$PROMPT"
    }
  ],
  "temperature": 0.1,
  "max_tokens": 2048
}
EOF
)

# Prepare headers
HEADERS=(
  -H "Content-Type: application/json"
  -H "Authorization: Bearer $API_KEY"
)

if [ -n "$POSTHOG_API_KEY" ]; then
  HEADERS+=(-H "x-posthog-api-key: $POSTHOG_API_KEY")
fi

# Function to make API request with retry
make_request() {
  local attempt=${1:-1}

  if ! response=$(curl -s -w "\n%{http_code}" \
    --max-time 60 \
    -X GET \
    "${HEADERS[@]}" \
    "https://$API_HOST$API_PATH?prompt=$(echo "$PROMPT" | jq -Rr @uri 2>/dev/null || echo "$PROMPT" | sed 's/ /%20/g')" 2>/dev/null); then

    if [ $attempt -le "$MAX_RETRIES" ]; then
      echo "Request failed (attempt $attempt/$MAX_RETRIES), retrying in ${RETRY_DELAY}s..." >&2
      sleep "$RETRY_DELAY"
      make_request $((attempt + 1))
      return
    else
      echo "Request failed after $MAX_RETRIES attempts" >&2
      exit 1
    fi
  fi

  # Split response and status code
  response_body=$(echo "$response" | head -n -1)
  status_code=$(echo "$response" | tail -n 1)

  # Handle specific status codes
  case $status_code in
    404)
      echo "Kilocode API Error (404): Endpoint not found. Check API path: $API_PATH" >&2
      exit 1
      ;;
    405)
      echo "Kilocode API Error (405): Method not allowed. API may not support POST on this endpoint." >&2
      exit 1
      ;;
    429|5*)
      if [ $attempt -le "$MAX_RETRIES" ]; then
        echo "API Error ($status_code), retrying in ${RETRY_DELAY}s... (attempt $attempt/$MAX_RETRIES)" >&2
        sleep "$RETRY_DELAY"
        make_request $((attempt + 1))
        return
      fi
      ;;
  esac

  if [ "$status_code" -ge 400 ]; then
    echo "Kilocode API Error ($status_code): $response_body" >&2
    exit 1
  fi

  # Parse response
  if command -v jq >/dev/null 2>&1; then
    content=$(echo "$response_body" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    if [ -z "$content" ] || [ "$content" = "null" ]; then
      error_msg=$(echo "$response_body" | jq -r '.error.message // .error // "Unknown API error"' 2>/dev/null)
      echo "API Error: $error_msg" >&2
      exit 1
    fi
  else
    # Fallback parsing without jq
    content=$(echo "$response_body" | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//' | sed 's/"$//')
    if [ -z "$content" ]; then
      echo "Failed to parse response (jq not available): $response_body" >&2
      exit 1
    fi
  fi

  # Clean up markdown formatting
  content=$(echo "$content" | sed 's/```json//g' | sed 's/```//g' | sed 's/^ *//;s/ *$//')

  echo "$content"
}

# Make the request
make_request