# ImmoGestion Agent Guide

## What this is

Quebec leasing automation engine — Node.js REST API backend for managing buildings, leases, tenants, payments, renewals, SMS campaigns, and analytics. Flutter web frontend served via Docker.

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
| `routes/`      | Express route definitions (16 route files)     |
| `database/`    | Connection pool, Drizzle schema                |
| `middleware/`   | Auth, rate limiting, validation                |
| `utils/`       | Logger, API response helpers                   |

### Key services

| Service                    | Purpose                                        |
| -------------------------- | ---------------------------------------------- |
| `twilio.service.js`        | SMS sending via Twilio                         |
| `sms.service.js`           | SMS campaign management                        |
| `email.service.js`         | Email sending (Nodemailer)                     |
| `facebook.service.js`      | Facebook Lead Ads integration                  |
| `messenger-bot.service.js` | Facebook Messenger chatbot                     |
| `notification.service.js`  | Push/multi-channel notifications               |
| `scheduler.service.js`     | Cron jobs (renewals, payments, reminders)      |
| `weekly-report.service.js` | Weekly analytics report generation             |
| `analytics.service.js`     | Business metrics and KPIs                      |

### Database tables (Drizzle/PostgreSQL)

- `users` — admin login accounts
- `buildings` — property management
- `leases` — tenant lease tracking
- `payments` — rent payment records
- `renewals` — lease renewal pipeline

### Frontend

`services/flutter-web/` — built Flutter web app, served via nginx in Docker. Static files, no server-side rendering.

## Conventions

- **Branding**: ImmoGestion — preserve exactly
- **JS files**: CommonJS (`require`), `kebab-case.js`
- **Tests**: `*.test.js` in `__tests__/` inside the service
- **Commits**: conventional commits; automated commits use `ai(AgentName): description`
- **No comments** in code unless asked
- **Language**: Quebec French for user-facing strings, English for code

## Key gotchas

- **Tests location**: Tests live in `services/api-backend/__tests__/`, not a separate top-level directory
- **Test default**: `npm test` skips integration tests (uses `--testPathIgnorePatterns='integration'`)
- **Production safety**: Server enforces `JWT_SECRET` >= 32 chars and specific `ALLOWED_ORIGINS` in production
- **Trust proxy**: Auto-set to 1 in production (behind reverse proxy)
- **Drizzle ORM**: Schema in `src/database/schema.js`, migrations in `migrations/`
- **Express version**: Currently Express 4 (not 5)
