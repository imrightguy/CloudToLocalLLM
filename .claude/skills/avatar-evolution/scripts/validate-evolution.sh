#!/bin/bash
# Validate Avatar Evolution Prerequisites
#
# Usage:
#   ./validate-evolution.sh <target_stage>
#
# Example:
#   ./validate-evolution.sh knowledge_seeker

set -euo pipefail

TARGET_STAGE="${1:-knowledge_seeker}"
ROUTER_URL="${ROUTER_URL:-http://localhost:1337}"

echo "🔍 Avatar Evolution Validation"
echo "==============================="
echo "Target stage: $TARGET_STAGE"
echo ""

# Get current avatar state
echo "Fetching current avatar state..."
if ! command -v curl &> /dev/null; then
  echo "❌ Error: curl not installed"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq not installed"
  exit 1
fi

state=$(curl -s "$ROUTER_URL/avatar/state" 2>&1)

if ! echo "$state" | jq empty 2>/dev/null; then
  echo "❌ Error: Failed to fetch avatar state"
  echo "Make sure the router server is running on port 1337"
  echo "Response: $state"
  exit 1
fi

current_stage=$(echo "$state" | jq -r '.evolutionStage // "unknown"')
deep_conversations=$(echo "$state" | jq -r '.evolutionCriteria.deepConversationCount // 0')
avg_novelty=$(echo "$state" | jq -r '.evolutionCriteria.averageNoveltyScore // 0')

echo "Current stage: $current_stage"
echo "Deep conversations: $deep_conversations"
echo "Average novelty: $avg_novelty"
echo ""

# Define stage requirements
case "$TARGET_STAGE" in
  curious_explorer)
    req_deep=0
    req_novelty=0.0
    ;;
  knowledge_seeker)
    req_deep=5
    req_novelty=0.5
    ;;
  wise_companion)
    req_deep=15
    req_novelty=0.6
    ;;
  enlightened_guide)
    req_deep=30
    req_novelty=0.7
    ;;
  *)
    echo "❌ Error: Unknown stage '$TARGET_STAGE'"
    echo "Valid stages: curious_explorer, knowledge_seeker, wise_companion, enlightened_guide"
    exit 1
    ;;
esac

# Validate
echo "Validation for: $TARGET_STAGE"
echo "------------------------------"
echo "Required deep conversations: $req_deep (you have: $deep_conversations)"
echo "Required average novelty: $req_novelty (you have: $avg_novelty)"
echo ""

# Check requirements using awk for floating point comparison
novelty_pass=$(echo "$avg_novelty >= $req_novelty" | awk '{print ($1+0)==1}')

if [ "$deep_conversations" -ge "$req_deep" ] && [ "$novelty_pass" -eq 1 ]; then
  echo "✅ Evolution prerequisites met!"
  echo ""
  echo "You can request evolution with:"
  echo "  curl -X POST $ROUTER_URL/avatar/evolution/request \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"stage\":\"$TARGET_STAGE\",\"reason\":\"Prerequisites met\"}'"
  exit 0
else
  echo "❌ Evolution prerequisites not met"
  echo ""
  if [ "$deep_conversations" -lt "$req_deep" ]; then
    echo "  → Need $((req_deep - deep_conversations)) more deep conversations"
  fi
  if [ "$novelty_pass" -eq 0 ]; then
    echo "  → Need higher novelty scores (current: $avg_novelty, required: $req_novelty)"
  fi
  exit 1
fi
