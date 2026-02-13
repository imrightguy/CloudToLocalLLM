#!/bin/bash
# Block edits to sensitive files (.env, secrets, keys, etc.)

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Check if file path matches any blocked pattern
if [[ "$FILE_PATH" == *.secret.yaml ]] || \
   [[ "$FILE_PATH" == */.env.production ]] || \
   [[ "$FILE_PATH" == */.env ]] || \
   [[ "$FILE_PATH" == */secrets/** ]] || \
   [[ "$FILE_PATH" == *.key ]]; then
  echo "Blocked: Cannot edit sensitive file: $FILE_PATH" >&2
  exit 2  # Exit code 2 = blocking error
fi

exit 0  # Allow the edit
