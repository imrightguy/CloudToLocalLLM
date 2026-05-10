# ImmoGestion

Leasing automation engine for Quebec landlords, centered on marketplace inbound messages and visit coordination.

## 🏗️ Architecture

- **Flutter web app** (`lib/`) - Public landing page plus authenticated app surface
- **Dart service layer** (`lib/services/`) - Service classes consuming REST APIs
- **Demo data and fixtures** (`lib/data/`) - Seeded data for the live demo and tests

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome
```

## 🎯 Demo Scope

The current public demo is intentionally narrow:

1. a lead arrives
2. the lead is qualified and assigned
3. a visit is scheduled and confirmed
4. the team follows up by SMS
5. the outcome is visible in the workflow

These demo-critical flows are backed by seeded demo company data rather than live upstream records:
- lead inbox / lead list
- one lead detail view
- one visit schedule or visit detail view
- the confirmation SMS / confirmation link flow
- the status change or outcome update after the visit

Marketplace demo/live boundary:
- set `MARKETPLACE_DATA_MODE=seeded` (or `demo` / `mock`) to keep inbox/timeline/message/visit workflows on demo-tagged leads only
- `/api/marketplace/inbox`
- `/api/marketplace/leads/:leadId/timeline`
- `/api/marketplace/leads/:leadId/messages`
- `/api/marketplace/leads/:leadId/visits`
- Messenger policy-aware follow-ups stay local in seeded mode and do not call live Messenger or SMS transports

What can wait:
- analytics dashboards
- settings pages
- employee management
- document management
- broad reporting views
- deep admin/config screens
- mobile builds or platform variants

## 🤝 Team Operating Model

See `docs/TEAM-OWNERSHIP-AND-REVIEW-CADENCE.md` for the cross-team ownership map and roadmap review cadence, and `docs/MESSAGE-TO-VISIT-OPERATING-METRICS.md` for the core funnel scorecard.

## 📁 Project Structure

```
ImmoGestion/
├── lib/                      # Flutter app
│   ├── screens/             # App screens (dashboard, pipeline, buildings, visits, etc.)
│   ├── services/            # Dart service classes (API, auth, leads, buildings, etc.)
│   ├── data/                # Demo data
│   ├── models.dart          # Data models
│   └── main.dart            # Entry point
├── assets/                   # Static assets
├── test/                     # Unit and integration tests
├── analysis_options.yaml     # Dart linter config
└── pubspec.yaml              # Dependencies
```

## 🎯 Target Market

- **Quebec landlords** with multi-property portfolios
- **Property managers** needing automation tools
- **Real estate investors** requiring analytics
- **Small agencies** managing 5-50 properties

## 📌 Current Status

- Public landing page and app login wall are the public entry points
- Core web workflow is the launch focus; mobile builds are deferred
- The repo is in demo-hardening mode, not broad feature-expansion mode

## 📧 Contact

- **Email**: simon@immogestion.ca
- **Demo**: Public landing at immogestion.app; app login at app.immogestion.app
- **Focus**: Streamlined leasing automation for local market