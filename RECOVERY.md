# RECOVERY.md

This workspace uses **Notion as the external recovery anchor**.

If context is thin or the session is fresh, read `SESSION_REENTRY.md` first.

If you need the deeper recovery flow, read `SESSION_RECOVERY_PLAN.md` after that.

## Canonical Recovery Source

Primary external source:
- **ZoidBot Notebook** in Notion

Recovery structure inside the notebook:
- Read Me First
- Current Snapshot
- New Session Recovery Plan
- Identity
- User Profile
- Operating Preferences
- Integrations & Environment
- existing Projects database
- Durable Memory database
- Change Log database

## Recovery Rule

If this workspace is lost, reinstalled, or bootstrapped fresh:

1. Read the Notion notebook first
2. Restore `IDENTITY.md`
3. Restore `USER.md`
4. Restore `AGENTS.md` and `SOUL.md`
5. Restore behavior/preferences from Notion
6. Review durable memory and active projects
7. Rebuild local files from that canonical context

## Sync Direction

### Notion → Local
Use for:
- identity
- user profile
- durable preferences
- durable setup knowledge
- high-value long-term memory

### Local → Notion
Use for:
- confirmed preference changes
- important long-term decisions
- recovery-relevant setup changes
- durable project context worth surviving reinstall

## Do Not Store in Notion

- raw secrets
- API keys
- passwords
- session tokens
- noisy temporary scratch notes

## Notes

- Notion is the durable memory anchor.
- Local files are the live runtime layer.
- Daily memory files remain the short-term scratchpad.
