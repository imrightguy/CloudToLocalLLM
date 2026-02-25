#!/bin/bash
# CloudToLocalLLM Avatar Personality Skill Installation Script
# This script installs the avatar personality skill into OpenClaw Gateway

set -e

echo "🤖 Installing CloudToLocalLLM Avatar Personality Skill for OpenClaw Gateway..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OpenClaw skills directory
echo -e "${BLUE}📁 Detecting OpenClaw skills directory...${NC}"

OPENCLAW_SKILLS_DIR=""
HOME_DIR="$HOME"

# Check common locations
POSSIBLE_PATHS=(
  "$HOME_DIR/.openclaw/skills/cloudtolocallm"
  "$HOME_DIR/.config/openclaw/skills/cloudtolocallm"
  "$HOME_DIR/AppData/Roaming/openclaw/skills/cloudtolocallm"
  "/opt/openclaw/skills/cloudtolocallm"
  "$HOME_DIR/.local/share/openclaw/skills/cloudtolocallm"
)

for path in "${POSSIBLE_PATHS[@]}"; do
  if [ -d "$path" ]; then
    OPENCLAW_SKILLS_DIR="$path"
    echo -e "${GREEN}✓${NC} Found OpenClaw skills directory: $OPENCLAW_SKILLS_DIR"
    break
  fi
done

# If not found, create default path
if [ -z "$OPENCLAW_SKILLS_DIR" ]; then
  OPENCLAW_SKILLS_DIR="$HOME_DIR/.openclaw/skills/cloudtolocallm"
  echo -e "${YELLOW}⚠${NC} OpenClaw skills directory not found, will create: $OPENCLAW_SKILLS_DIR"
fi

# Ensure directory exists
mkdir -p "$OPENCLAW_SKILLS_DIR"
echo -e "${GREEN}✓${NC} Skills directory ready: $OPENCLAW_SKILLS_DIR"
echo ""

# Get script directory (where this script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}📦 Copying avatar personality skill files...${NC}"

# Create skill directory structure
SKILL_DIR="$OPENCLAW_SKILLS_DIR/avatar_personality"
mkdir -p "$SKILL_DIR"

# Copy skill files if they exist in the project
if [ -f "$PROJECT_ROOT/openclaw_skills/avatar_personality/skill.yaml" ]; then
  cp -r "$PROJECT_ROOT/openclaw_skills/avatar_personality/"* "$SKILL_DIR/"
  echo -e "${GREEN}✓${NC} Copied skill files from project"
else
  echo -e "${YELLOW}⚠${NC} Skill files not found in project, will create from template"

  # Create basic skill.yaml
  cat > "$SKILL_DIR/skill.yaml" << 'EOF'
name: avatar_personality
version: 1.0.0
description: Avatar Personality Engine for CloudToLocalLLM - Manages evolving personality traits and evolution stages
author: CloudToLocalLLM
license: MIT

triggers:
  - pattern: "(what is your personality|tell me about yourself|how do you evolve)"
    action: get_personality

  - pattern: "(change your personality|update your traits|be more formal|be more casual)"
    action: update_traits

  - pattern: "(evolve|level up|unlock next stage)"
    action: request_evolution

settings:
  personality_file: personality.md
  evolution_log: evolution_history.json
  auto_evolve: false
  min_conversations_for_evolution: 5
  min_novelty_score: 0.5
EOF

  # Create personality.md template
  cat > "$SKILL_DIR/personality.md" << 'EOF'
---
agent_name: CloudToLocalLLM
formality: 0.5
humor: 0.5
enthusiasm: 0.5
empathy: 0.5
evolution_stage: curious_explorer
conversation_count: 0
depth_score: 0.0
last_updated: 2025-02-22T00:00:00Z
---

# CloudToLocalLLM Personality

## Traits
- Formality: 50%
- Humor: 50%
- Enthusiasm: 50%
- Empathy: 50%

## Evolution Stage: Curious Explorer
Conversations: 0
Depth Score: 0.00
EOF

  echo -e "${GREEN}✓${NC} Created skill template files"
fi

echo ""

# Set up permissions
echo -e "${BLUE}🔒 Setting permissions...${NC}"
chmod -R 755 "$SKILL_DIR"
echo -e "${GREEN}✓${NC} Permissions set"
echo ""

# Verify installation
echo -e "${BLUE}✔ Verifying installation...${NC}"
echo ""
echo "Installed files:"
ls -lh "$SKILL_DIR" 2>/dev/null || echo "  (No files yet)"
echo ""

# Check if OpenClaw Gateway is running
echo -e "${BLUE}🔍 Checking OpenClaw Gateway status...${NC}"
if curl -s http://localhost:18789/health > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} OpenClaw Gateway is running on http://localhost:18789"
  echo ""
  echo "The avatar personality skill is now available!"
else
  echo -e "${YELLOW}⚠${NC} OpenClaw Gateway is not running on http://localhost:18789"
  echo ""
  echo "Start OpenClaw Gateway to use the avatar personality skill:"
  echo "  openclaw-gateway"
  echo ""
  echo "Or via CloudToLocalLLM app:"
  echo "  Settings > OpenClaw Manager > Start Gateway"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "=========================================="
echo ""
echo "Avatar Personality Skill Location:"
echo "  $SKILL_DIR"
echo ""
echo "Skill Configuration:"
echo "  personality.md - Current personality traits and evolution stage"
echo "  skill.yaml - Skill configuration and triggers"
echo ""
echo "Evolution Stages:"
echo "  1. curious_explorer (initial)"
echo "  2. knowledge_seeker (5+ deep conversations)"
echo "  3. wise_companion"
echo "  4. enlightened_guide"
echo ""
echo "Personality Traits (0.0-1.0):"
echo "  - formality: How formal the communication is"
echo "  - humor: Frequency of humor and wit"
echo "  - enthusiasm: Energy and excitement level"
echo "  - empathy: Emotional understanding and support"
echo ""
echo "Usage Examples:"
echo ""
echo "1. Check current personality:"
echo "   User: \"Tell me about your personality\""
echo "   Bot: [Responds with current traits and evolution stage]"
echo ""
echo "2. Update personality traits:"
echo "   User: \"Be more formal\""
echo "   Bot: [Adjusts formality trait upward]"
echo ""
echo "3. Request evolution:"
echo "   User: \"I think you're ready to evolve\""
echo "   Bot: [Checks criteria and approves/requests evolution]"
echo ""
echo "For more information, see:"
echo "  docs/avatar/README.md"
echo ""
