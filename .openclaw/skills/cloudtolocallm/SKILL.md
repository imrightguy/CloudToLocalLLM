# CloudToLocalLLM Avatar Personality Skill

**Version**: 1.0.0
**Author**: CloudToLocalLLM
**Description**: Enables OpenClaw agents to develop unique personalities that evolve organically through meaningful conversations.

---

## Overview

This skill provides personality injection, self-reflection, and evolution capabilities for OpenClaw agents. It integrates with CloudToLocalLLM via:

1. **Drift Database** (primary storage via Tailscale)
2. **Markdown Files** (backup/fallback storage)
3. **REST API** (CloudToLocalLLM router server on port 1337)

---

## Personality Traits

| Trait | Range | Description |
|-------|-------|-------------|
| `formality` | 0.0-1.0 | Casual (0) to Professional (1) |
| `humor` | 0.0-1.0 | Serious (0) to Playful (1) |
| `enthusiasm` | 0.0-1.0 | Calm (0) to Energetic (1) |
| `empathy` | 0.0-1.0 | Direct (0) to Warm (1) |

---

## Evolution Stages

| Stage | Requirement | Description |
|-------|-------------|-------------|
| `base` | Default | Initial personality state |
| `stage1` | 5+ deep conversations, avg novelty > 0.5 | Enhanced awareness |
| `stage2` | 15+ deep conversations, avg novelty > 0.6 | Mature personality |
| `final` | 30+ deep conversations, avg novelty > 0.7 | Fully evolved |

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/avatar/state` | GET | Get current avatar state |
| `/avatar/traits` | POST | Update personality traits |
| `/avatar/evolution/request` | POST | Request evolution to next stage |

---

## Files

- `index.ts` - Main skill logic (personality injection, self-reflection)
- `personality.md` - Personality state backup (agent_name, traits, evolution_stage)
- `memory.md` - Conversation memory backup (summaries)
- `context.md` - User context backup (patterns, preferences)

---

## Usage

The skill automatically:
1. Loads personality state from markdown or API
2. Injects personality traits into system prompts
3. Monitors conversation depth for evolution triggers
4. Syncs state changes to markdown backup

---

## Configuration

Set in OpenClaw config:
```json
{
  "cloudtolocallm": {
    "apiUrl": "http://localhost:1337",
    "syncInterval": 60000
  }
}
```
