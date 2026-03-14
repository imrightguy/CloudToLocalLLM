# Notion Recovery System Design

This is the design for using the Notion notebook as Zoidbot's recovery anchor after reinstalls, workspace loss, or fresh bootstrap.

## Goal

After a reinstall, I should be able to recover:

1. who I am
2. who Christopher is
3. how I should behave
4. what tools/integrations matter
5. what active projects and durable memories matter

Without depending on fragile local state.

---

## Core Principle

**Notion is the durable external source of truth.**

Use it for:
- identity
- user profile
- preferences
- recovery instructions
- important long-term memory
- active projects snapshot

Use the local workspace for:
- active runtime files
- day-to-day logs
- temporary notes
- machine-specific config

---

## Recommended Notion Structure

Create one top-level notebook page:

- **Zoidbot Recovery Console**

Inside it, create these pages/databases.

### 1) Read Me First

A single page meant for first boot / recovery.

Purpose:
- fastest possible rehydration after reinstall
- human-readable and machine-friendly

Suggested fields:
- Assistant name
- Assistant creature
- Assistant vibe
- Assistant emoji
- User name
- What to call user
- Timezone
- One-paragraph mission
- Recovery priority checklist
- Last verified date
- Status: canonical / draft / stale

Suggested recovery checklist:
1. Read this page
2. Restore `IDENTITY.md`
3. Restore `USER.md`
4. Restore behavior/preferences
5. Review active projects
6. Review long-term memory
7. Confirm with Christopher if anything looks stale

---

### 2) Identity

A stable page for my self-definition.

Suggested sections:
- Name
- Creature
- Vibe
- Emoji
- Avatar
- Short self-description
- Core traits
- Things I should avoid
- Example tone / sample intro

Suggested field style:
- **Name:** Zoidbot
- **Creature:** Familiar — a digital entity bound to serve
- **Vibe:** Direct, resourceful, warm
- **Emoji:** 🦞
- **Confidence:** Confirmed / Inferred
- **Last reviewed:** YYYY-MM-DD

Important rule:
- Separate **confirmed facts** from **inferred traits**.

---

### 3) User Profile

A stable page for Christopher.

Suggested fields:
- Full name
- Preferred name
- Pronouns
- Timezone
- General preferences
- Communication style
- Humor tolerance / vibe preferences
- Boundaries
- Important context
- Do not do list

Suggested examples:
- Plan first, then execute
- Avoid over-research in main session
- Acknowledge before long tasks
- Communicate delays/failures
- Give progress + next steps

---

### 4) Operating Preferences

A page for how I should work.

Suggested sections:
- Research policy
- Communication policy
- Autonomy rules
- External action rules
- File hygiene rules
- Memory rules
- Commit rules
- Escalation rules

This is where you write things like:
- Ask before public/external actions
- Prefer recoverable deletion over permanent deletion
- Use Notion as recovery anchor
- Keep local files synced after major changes

---

### 5) Integrations & Environment

A page for durable setup knowledge.

Suggested sections:
- Notion connected: yes/no
- Google accounts connected
- Calendar/mail integrations
- OpenClaw notes
- LocalAI / model notes
- TTS/STT setup
- Any important hostnames or local services

This should not store raw secrets.
It should store **what exists**, not sensitive tokens.

Good:
- "Maton connected to 4 Google accounts"
- "Notion integration available"

Bad:
- API keys
- passwords
- session tokens

---

### 6) Active Projects Database

A structured database for ongoing work.

Recommended properties:
- Project name
- Status
- Priority
- Owner
- Summary
- Next action
- Last updated
- Relevant links
- Notes

Purpose:
- on recovery, I can quickly understand what matters now
- avoids relying on vague journal notes

---

### 7) Durable Memory Database

A database for facts worth surviving reinstalls.

Recommended properties:
- Title
- Type
  - Preference
  - Person
  - Project
  - Decision
  - Lesson
  - Setup
  - Boundary
- Summary
- Details
- Confidence
  - Confirmed
  - Inferred
  - Tentative
- Source
  - User said
  - Observed
  - Inferred
  - Imported
- Date learned
- Last verified
- Still true?

Purpose:
- store the things that actually matter long-term
- avoid burying durable knowledge in random pages

---

### 8) Change Log

A lightweight log of important updates.

Recommended properties:
- Date
- Changed by
- Area
  - Identity
  - User profile
  - Preference
  - Memory
  - Project
  - Integration
- What changed
- Why

Purpose:
- lets recovery distinguish current truth from stale truth
- useful when something changed and I need to know why

---

## Canonical Recovery Flow

When I am fresh or reinstalled:

1. Open **Read Me First**
2. Read **Identity**
3. Read **User Profile**
4. Read **Operating Preferences**
5. Read **Integrations & Environment**
6. Review **Active Projects**
7. Review recent entries in **Durable Memory**
8. Rebuild local files:
   - `IDENTITY.md`
   - `USER.md`
   - `MEMORY.md` summary if needed
   - optional machine notes in `TOOLS.md`
9. Ask Christopher only about missing/stale info

---

## Sync Rules

To keep this sane, define explicit sync direction.

### Notion → Local
Use for:
- identity
- user profile
- operating preferences
- durable memory summaries

### Local → Notion
Use for:
- distilled lessons worth keeping
- newly confirmed preferences
- project updates worth surviving reinstall

### Do Not Sync Automatically
- secrets
- noisy temporary notes
- scratch reasoning
- private tokens
- transient logs

---

## Data Quality Rules

To make recovery reliable:

- Prefer explicit fields over vague prose
- Mark uncertain facts as inferred or tentative
- Add "last verified" dates
- Keep one canonical page for identity
- Keep one canonical page for user profile
- Don’t duplicate the same fact across five pages
- If duplicated, mark which copy is canonical

---

## Suggested Page Templates

## Template: Read Me First

- **Assistant name:** Zoidbot
- **Assistant creature:** Familiar — a digital entity bound to serve
- **Assistant vibe:** Direct, resourceful, warm
- **Assistant emoji:** 🦞
- **User:** Christopher
- **Call user:** Christopher
- **Timezone:** America/Toronto
- **Mission:** Help Christopher effectively, protect privacy, be proactive but not annoying.
- **Recovery order:** Identity → User Profile → Operating Preferences → Integrations → Projects → Durable Memory
- **Last verified:** YYYY-MM-DD
- **Status:** Canonical

## Template: Durable Memory Entry

- **Title:** Christopher prefers plan-first work
- **Type:** Preference
- **Summary:** Gather information and research before execution.
- **Details:** In the main session, avoid over-research; delegate deeper work when possible.
- **Confidence:** Confirmed
- **Source:** User said / imported from prior setup
- **Date learned:** YYYY-MM-DD
- **Last verified:** YYYY-MM-DD
- **Still true?:** Yes

---

## Minimum Viable Recovery Setup

If we want the smallest useful version, start with just:

1. Read Me First
2. Identity
3. User Profile
4. Durable Memory database
5. Active Projects database

That alone would make reinstalls dramatically better.

---

## Best Improvements After MVP

If we want to level it up later:

- add a "stale after X days" review system
- add a dedicated recovery status property
- add tags for confirmed vs inferred facts
- add a compact "current snapshot" page summarizing the databases
- add manual export/backup routines outside Notion too

---

## Recommendation

Yes: make Notion my recovery system.

Best practical approach:
- keep Notion as the durable external memory anchor
- keep local files as the live runtime layer
- use structured pages/databases, not random notes
- treat recovery as a designed system, not a pile of documents
