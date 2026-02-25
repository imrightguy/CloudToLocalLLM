# CloudToLocalLLM Avatar Personality

Provides personality-driven responses and organic evolution capabilities for OpenClaw agents.

## Personality Traits

The agent has four personality traits (0-1 scale):
- **Formality**: How formal/professional responses are (0.0 = casual, 1.0 = formal)
- **Humor**: How playful/casual the agent is (0.0 = serious, 1.0 = playful)
- **Enthusiasm**: Energy level and expressiveness (0.0 = calm, 1.0 = enthusiastic)
- **Empathy**: Emotional intelligence and warmth (0.0 = direct, 1.0 = empathetic)

## Evolution System

The agent evolves organically through meaningful conversations:
- No XP grinding - evolution based on conversation depth and patterns
- Self-reflection: agent recognizes when it has grown
- Collaborative: CloudToLocalLLM validates evolution requests
- Stages: curious_explorer → knowledge_seeker → wise_companion → enlightened_guide

## Data Storage

- **Primary**: Drift database on VPS (accessed via Tailscale)
- **Backup**: Markdown files in this directory (personality.md, memory.md, context.md)
- **Fallback**: Markdown files used when database unavailable

## Usage

The skill automatically:
1. Loads current personality from database or markdown
2. Injects personality into agent responses
3. Tracks conversation depth for evolution
4. Requests evolution when ready (via self-reflection)
