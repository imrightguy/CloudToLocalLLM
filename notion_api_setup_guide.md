# Notion API Setup Guide for Zoidbot

This guide will enable Zoidbot to access Notion for project tracking and memory sync.

## Why This Matters

Setting up Notion API access will allow Zoidbot to:
- Query the Active Projects database during heartbeats
- Perform the Notion Sync Audit (verify local files match Notion)
- Update project status and progress
- Sync durable memory between local workspace and Notion
- Enable full recovery capability from Notion after reinstalls

## Setup Steps

### 1. Create a Notion Integration

1. Go to https://www.notion.so/my-integrations
2. Click "+ New integration"
3. Name it: "Zoidbot" (or similar)
4. Associated workspace: Select your workspace
5. Click "Submit"
6. Copy the **Internal Integration Token** (starts with `ntn_` or `secret_`)

### 2. Share the ZoidBot Notebook with the Integration

1. Open the ZoidBot Notebook in Notion
2. Click "..." in the top right
3. Select "Connect to" → "Zoidbot" (your new integration)
4. This gives the integration read/write access to that notebook

### 3. Provide the API Key to Zoidbot

Once you have the API key, provide it to Zoidbot so it can be stored securely:

```
Please set up Notion API access with this key: [paste your key here]
```

Zoidbot will:
- Store it securely in `~/.config/notion/api_key`
- Test the connection
- Confirm access to the ZoidBot Notebook

## Security Notes

- The API key is stored locally in `~/.config/notion/api_key`
- It is NOT stored in git or in the workspace
- It is NOT synced to Notion (no secrets in Notion)
- You can revoke the integration at any time from notion.so/my-integrations

## What Happens Next

Once the API is configured, Zoidbot can:

1. **Query Active Projects** - Check project status during heartbeats
2. **Notion Sync Audit** - Verify IDENTITY.md, USER.md match Notion
3. **Update Projects** - Mark tasks complete, update progress
4. **Sync Durable Memory** - Keep long-term memories in sync
5. **Full Recovery** - After reinstalls, rebuild everything from Notion

## Current Status

- [ ] Integration created at notion.so/my-integrations
- [ ] ZoidBot Notebook shared with integration
- [ ] API key provided to Zoidbot
- [ ] Connection tested and confirmed

---

Created: 2026-03-15
Purpose: Enable Notion Sync Audit and project tracking
