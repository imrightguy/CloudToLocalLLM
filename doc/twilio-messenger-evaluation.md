# Twilio as Facebook Messenger Automation Layer — Evaluation

**Issue:** IMM-534 / GitHub #22  
**Date:** 2025-05-10  
**Recommendation:** SUPPLEMENT — use Twilio Conversations as a unified messaging backbone

---

## 1. Current Architecture

### 1.1 Facebook Messenger (Direct Meta Graph API)

**Files:**
- `services/api-backend/src/services/facebook.service.js` — Meta Graph API v18.0 wrapper
- `services/api-backend/src/services/messenger-bot.service.js` — Full conversation state machine (1531 lines)
- `services/api-backend/src/controllers/facebook-webhook.controller.js` — Webhook handler
- `services/api-backend/src/routes/facebook.routes.js` — `/api/webhooks/facebook` routes

**Capabilities:**
- Send text messages, quick replies, generic template cards via Meta Graph API
- Conversation state machine with 10 states (NEW → DONE) for lead qualification
- French-first i18n with English fallback
- Lead Ad webhook ingestion (deduplication, auto-lead creation)
- User profile fetching (name, locale, profile pic)
- Communication logging to `communication_logs` table
- Messenger conversation persistence to `messenger_conversations` table
- 24-hour messaging window policy with automatic SMS fallback via Twilio

**Environment variables:** `FB_PAGE_ACCESS_TOKEN`, `FB_VERIFY_TOKEN`

### 1.2 Twilio (SMS only — current)

**File:** `services/api-backend/src/services/twilio.service.js` (144 lines)

**Capabilities:**
- SMS send via `twilio.messages.create()`
- Incoming SMS keyword parsing (French + English)
- Simple init from `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`

**Used by:** `sms.service.js` for visit confirmations, tenant access requests, morning-of reminders, occupant replies, lead follow-up SMS, and the Messenger bot's 24h window SMS fallback.

### 1.3 SMS Service (business layer)

**File:** `services/api-backend/src/services/sms.service.js` (2254 lines)

Comprehensive SMS business logic including visit confirmation, tenant confirmation with URL tokens, occupant access requests/replies, morning-of reminders, lead follow-up, SMS campaigns, opt-out handling, and renewal offer SMS.

---

## 2. What Twilio Could Add

### 2.1 Twilio Conversations

Twilio Conversations provides a unified API for multi-channel messaging:
- **SMS** (already in use)
- **WhatsApp** — huge for Quebec landlords; many tenants prefer WhatsApp
- **Facebook Messenger** — via Twilio's Messenger integration (requires a Twilio Messenger channel)
- **Web/chat** — in-app chat widget
- **Google Business Messages** — emerging channel

Key benefits:
- Single API (`twilio.conversations.v1`) for all channels
- Unified conversation threading across channels
- Built-in message storage and retrieval
- Webhook integration for incoming messages across all channels
- Participant management (customer, agent, bot)

### 2.2 Twilio WhatsApp Business API

- Direct WhatsApp messaging to tenants (very popular in Quebec's diverse population)
- Message templates for proactive outreach (visit reminders, lease renewals)
- Rich media support (images of properties, PDF documents)
- 24-hour session window similar to Messenger but with template-based workarounds
- Requires Meta Business Manager verification (same entity that controls FB Page)

### 2.3 Twilio Messenger Channel

Twilio can proxy Facebook Messenger messages through its API instead of calling Meta Graph API directly. However:
- Adds a layer of abstraction that reduces control over Meta-specific features
- The current direct Graph API integration already works well for Messenger
- Quick replies, generic templates, and other rich Messenger features may be limited or require workarounds through Twilio's messaging API

---

## 3. Gap Analysis

| Feature | Current (Direct Meta API + Twilio SMS) | With Twilio Conversations |
|---------|---------------------------------------|---------------------------|
| FB Messenger send/receive | Yes (direct Graph API) | Yes (via Twilio channel) |
| SMS send/receive | Yes (Twilio SMS) | Yes (same) |
| WhatsApp | No | Yes |
| Unified conversation threading | Partial (separate FB + SMS) | Yes (cross-channel) |
| Rich Messenger templates | Yes (quick replies, cards) | Limited |
| Lead Ad webhooks | Yes (direct) | Needs custom integration |
| 24h window fallback to SMS | Yes (implemented) | Built-in cross-channel |
| Multi-agent conversation | No (1:1 bot only) | Yes (participant model) |
| Message history/search | Custom (communication_logs) | Twilio + custom |
| Cost | Graph API free + Twilio SMS | Twilio per-message fees on all channels |

---

## 4. Recommendation: SUPPLEMENT

**Do not replace the direct Meta Graph API integration. Supplement it with Twilio Conversations for WhatsApp and unified threading.**

### Rationale

1. **The current Messenger integration is mature and working.** The 1531-line `messenger-bot.service.js` has a sophisticated state machine, i18n, lead qualification, visit scheduling, communication logging, and 24h window fallback. Replacing this with Twilio's Messenger proxy would lose rich template support and add latency.

2. **WhatsApp is the real gap.** Quebec has a large immigrant population that heavily uses WhatsApp. Adding WhatsApp via Twilio Conversations opens a high-value channel without disrupting the existing Messenger flow.

3. **Twilio Conversations provides cross-channel threading.** A tenant who starts on Messenger and later switches to WhatsApp/SMS can be tracked in a single conversation. This is the primary architectural benefit.

4. **Cost consideration.** Twilio Conversations charges per message per participant. For a small-medium landlord operation, this is acceptable. For high-volume scenarios (hundreds of tenants), the direct Graph API (free for Messenger) plus Twilio SMS remains cheaper for Messenger traffic.

5. **Lead Ad webhooks remain on direct Meta API.** Twilio Conversations does not handle Facebook Lead Ad webhooks. The current `processLeadAdWebhook` in `facebook.service.js` must stay on the direct Graph API path.

### Proposed Architecture

```
                    ┌─────────────────────┐
                    │   ImmoGestion API    │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼────────┐  ┌───▼──────┐  ┌──────▼───────┐
    │  Direct Meta API  │  │  Twilio  │  │  Twilio SMS  │
    │  (keep as-is)     │  │  Conv.   │  │  (keep)      │
    │  - Messenger bot  │  │  - WA    │  │  - Visit SMS │
    │  - Lead Ad hooks  │  │  - Chat  │  │  - Campaigns │
    │  - Rich templates │  │          │  │  - Fallback  │
    └───────────────────┘  └──────────┘  └──────────────┘
```

### Implementation Steps (if approved)

1. **Install `twilio` SDK upgrade** (already present) and enable Conversations API access
2. **Create `whatsapp.service.js`** — Twilio Conversations-based WhatsApp channel
3. **Create unified `conversation-router.service.js`** — routes incoming messages by channel, maintains cross-channel thread in `communication_logs`
4. **Add `/api/webhooks/twilio` endpoint** for WhatsApp/conversation incoming messages
5. **Extend `messenger-bot.service.js`** to share conversation state with the WhatsApp channel via the router
6. **Environment variables needed:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER` (existing) + `TWILIO_WHATSAPP_NUMBER` (new)
7. **Meta Business Manager verification** required for WhatsApp Business API access

### What NOT to change
- `facebook.service.js` — keep direct Graph API calls for Messenger
- `messenger-bot.service.js` — keep the state machine for Messenger conversations
- `twilio.service.js` — keep for direct SMS use cases
- Lead Ad webhook flow — remains on direct Meta API

---

## 5. Cost Estimate

| Channel | Current | With Twilio Conversations |
|---------|---------|--------------------------|
| FB Messenger | Free (Graph API) | Free (keep direct) |
| SMS | ~$0.0079/msg (Twilio) | ~$0.0079/msg (unchanged) |
| WhatsApp | N/A | ~$0.005/msg (Twilio) + template fees |
| Conversations API | N/A | ~$0.05/conversation/month |

For ~100 leads/month, estimated additional cost: **$5-15/month**.

---

## 6. Verdict

**SUPPLEMENT, do not replace.** Keep the direct Meta Graph API for Messenger (it works well and supports rich features). Add Twilio Conversations for WhatsApp access and cross-channel conversation threading. The existing 24h-window SMS fallback pattern in `messenger-bot.service.js` demonstrates the team already thinks in terms of multi-channel fallback — Twilio Conversations formalizes this pattern.

The highest-ROI next step is **WhatsApp via Twilio**, not replacing the existing Messenger integration.
