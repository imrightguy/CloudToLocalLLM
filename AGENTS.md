# ImmoGestion Agent Guide

## What this is

Quebec leasing automation engine — Node.js REST API backend for managing buildings, leases, tenants, payments, renewals, SMS campaigns, and analytics. Flutter web frontend served via Docker.

## Issue-scoped execution

If an issue gives concrete steps, follow those first and do not restart generic discovery (issue re-listing, GOAL/docs rereads, queue-health preflights, or skill-loading chatter) unless the issue explicitly asks for it or a missing prerequisite blocks execution. For issue-scoped replacement runs, the issue description plus the latest authoritative issue comments are the source of truth and must override broader repo guidance, stale continuity, and prior run trails when they conflict. If the issue already names exact credentials, URLs, IDs, or live API results, treat them as final and do not re-derive or question them unless the issue explicitly says they are missing or stale.

## Commands

### API Backend (`services/api-backend/`)

```
npm install                    # install deps
npm run dev                    # nodemon dev server
npm test                       # all tests (Jest, unit only by default)
npm run test:integration       # integration tests
npm run test:coverage          # with coverage
npm run lint                   # ESLint
npm run lint:fix               # ESLint with auto-fix
npm run migrate                # run database migrations
npm run seed                   # seed demo data
npm run seed:clear             # clear demo data
```

### Docker

```
docker compose up -d           # full stack (api + postgres + flutter-web)
docker compose -f docker-compose.prod.yml up -d  # production
```

### Agent commit/push helper

```
scripts/agent-push.sh --message "ai(AgentName): change summary" --files path/to/file [more/files]
scripts/agent-push.sh --message "ai(AgentName): change summary" --files path/to/file --verify 'exact test command'
```

- Node.js >=18, CommonJS (`require`)
- Database: PostgreSQL via Drizzle ORM
- Auth: JWT with refresh tokens (bcryptjs hashing)

## Architecture

### Backend structure (`services/api-backend/src/`)

| Path           | Purpose                                        |
| -------------- | ---------------------------------------------- |
| `server.js`    | Entry point — Express, CORS, helmet, swagger    |
| `config/`      | JWT config, Swagger spec                       |
| `controllers/` | Request handlers (18 controllers)              |
| `services/`    | Business logic — email, SMS, Facebook, Twilio, analytics, scheduler |
| `models/`      | Drizzle ORM table definitions (5 models)       |
| `routes/`      | Express route definitions (18 route files)     |
| `database/`    | Connection pool, Drizzle schema                |
| `middleware/`   | Auth, rate limiting, validation                |
| `utils/`       | Logger, API response helpers                   |

### Key services

| Service | Purpose |
| --- | --- |
| `twilio.service.js` | SMS sending via Twilio |
| `whatsapp.service.js` | WhatsApp messaging via Twilio Conversations |
| `conversation-router.service.js` | Cross-channel thread management (WhatsApp + SMS + Messenger) |
| `sms.service.js` | SMS campaign management |
| `email.service.js` | Email sending (Nodemailer) |
| `facebook.service.js` | Facebook Lead Ads integration |
| `messenger-bot.service.js` | Facebook Messenger chatbot |
| `notification.service.js` | Push/multi-channel notifications |
| `scheduler.service.js` | Cron jobs (renewals, payments, reminders) |
| `weekly-report.service.js` | Weekly analytics report generation |
| `analytics.service.js` | Business metrics and KPIs |

### Database tables (Drizzle/PostgreSQL)

- `users` — admin login accounts
- `buildings` — property management
- `units` — rental units within buildings
- `leases` — tenant lease tracking
- `payments` — rent payment records
- `renewal_offers` — lease renewal pipeline
- `visits` — property visit scheduling
- `leads` — lead tracking and pipeline
- `employees` — employee management
- `employee_assignments` — employee-to-lead assignments
- `employee_schedules` — employee availability scheduling
- `sms_campaigns` — SMS marketing campaigns
- `sms_logs` — SMS delivery logs
- `sms_queue` — SMS sending queue
- `sms_opt_outs` — SMS opt-out list
- `sms_templates` — SMS message templates
- `notifications` — in-app notifications
- `notification_preferences` — user notification settings
- `communication_logs` — multi-channel communication history
- `whatsapp_conversations` — WhatsApp conversation state tracking
- `documents` — document storage references
- `documents_leads` — document-lead associations
- `refresh_tokens` — JWT refresh token storage

### Frontend

`services/flutter-web/` — built Flutter web app, served via nginx in Docker. Static files, no server-side rendering.

## Conventions

- **Branding**: ImmoGestion — preserve exactly
- **JS files**: CommonJS (`require`), `kebab-case.js`
- **Tests**: `*.test.js` in `__tests__/` inside the service
- **Commits**: conventional commits; automated commits use `ai(AgentName): description`
- **Agent push rule**: when an agent changes code or workflow files and the user expects the work to land, the agent must verify the changed slice, commit only the intended files, and push the current branch. Do not leave verified code stranded in the local working tree. Use `scripts/agent-push.sh` with an explicit file list so dirty unrelated files do not get swept into the commit.
- **No comments** in code unless asked
- **Language**: Quebec French for user-facing strings, English for code

## Key gotchas


### Public demo / browser verification and Cloudflare routing

- HTTP 200 / curl is not enough for public demo readiness; use `/paperclip/ImmoGestion/scripts/browser-check.js https://app.immogestion.app/` and inspect browser-render evidence.
- Blank page, empty body text, CSP, CanvasKit, WASM, font, dynamic import, console/page errors, or render-blocking failed requests mean the demo is not ready.
- Normal OS/browser DNS and unforced HTTPS are decisive; Cloudflare API, DoH-only, `curl --resolve`, localhost, and origin-container health are diagnostic only.
- Cloudflare/API success and frontend usability are separate checks.
- `paperclip.immogestion.app` must stay private; do not expose it as the public demo.
- Christopher corrections must be reconciled into active issues and agent instructions immediately.

- **Tests location**: Tests live in `services/api-backend/__tests__/`, not a separate top-level directory
- **Test default**: `npm test` skips integration tests (uses `--testPathIgnorePatterns='integration'`)
- **Production safety**: Server enforces `JWT_SECRET` >= 32 chars and specific `ALLOWED_ORIGINS` in production
- **Trust proxy**: Auto-set to 1 in production (behind reverse proxy)
- **Drizzle ORM**: Schema in `src/database/schema.js`, migrations in `migrations/`
- **Express version**: Currently Express 4 (not 5)
- **Public/app boundary**: `https://immogestion.app/` is the public landing page. `https://app.immogestion.app/` is always behind a login page. Do not expose or build unauthenticated app-subdomain dashboards, property operations, tenant/payment/service-request pages, reports, or internal workflows unless Christopher explicitly marks a route public.
- **Public landing-page verification**: HTTP 200 / curl is not enough. For `immogestion.app`, agents must verify real browser rendering and console/page errors. Use `/paperclip/ImmoGestion/scripts/browser-check.js https://immogestion.app/` inside the Paperclip runtime. For Flutter/canvas rendering, empty body text alone is not failure if the screenshot shows the landing page. A blank page, CSP errors that block rendering, CanvasKit/WASM/font load blockers, or dynamic import failures mean the landing page is not ready.
- **App subdomain verification**: Browser tests should confirm `https://app.immogestion.app/` and non-landing operational routes require login/authorization rather than rendering public app content.
- **Cloudflare/public routing**: normal OS/browser DNS + unforced HTTPS checks are decisive. Cloudflare API, DoH-only, `curl --resolve`, localhost, or container-origin health can diagnose but do not prove user-visible readiness.
