# ImmoGestion — API Wiring Plan

> Comprehensive mapping of Flutter screens → Backend endpoints
> Generated from source analysis of `lib/` screens, `models.dart`, `demo_data.dart`, and `services/api-backend/src/`.

---

## Table of Contents

1. [Backend Endpoint Registry](#1-backend-endpoint-registry)
2. [Flutter Model → DB Schema Mapping](#2-flutter-model--db-schema-mapping)
3. [Screen-by-Screen Wiring Plan](#3-screen-by-screen-wiring-plan)
   - [HomeScreen (Accueil)](#31-homescreen-accueil)
   - [DashboardScreen (Tableau de bord)](#32-dashboardscreen-tableau-de-bord)
   - [PipelineScreen](#33-pipelinescreen)
   - [VisitsScreen](#34-visitsscreen)
   - [BuildingsScreen (Immeubles)](#35-buildingsscreen-immeubles)
4. [Cross-Cutting Concerns](#4-cross-cutting-concerns)
5. [Gaps & Recommendations](#5-gaps--recommendations)

---

## 1. Backend Endpoint Registry

All endpoints are mounted under `/api` (base). All require `Authorization: Bearer <accessToken>` except public routes.

| Prefix | Resource | Methods | Auth |
|--------|----------|---------|------|
| `/api/auth` | Authentication & Users | POST/GET/PUT/DELETE | Mixed |
| `/api/buildings` | Buildings & Units | CRUD | ✅ |
| `/api/employees` | Employees & Assignments | CRUD | ✅ |
| `/api/leads` | Leads & Pipeline | CRUD + Bulk | ✅ |
| `/api/visits` | Visits | CRUD + Status | ✅ |
| `/api/documents` | Documents | CRUD + Search + Approve/Reject | ✅ |
| `/api/schedules` | Employee Schedules | CRUD + Availability | ✅ |
| `/api/communications` | Communication Logs | Read/Log | ✅ |
| `/api/analytics` | Dashboard & Analytics | GET | ✅ |
| `/api/webhooks` | SMS & Facebook webhooks | POST | ❌ (public) |
| `/api/health` | Health check | GET | ❌ |

---

## 2. Flutter Model → DB Schema Mapping

| Flutter Model | DB Table | Key Fields | Notes |
|---------------|----------|------------|-------|
| `BuildingItem` | `buildings` | `id, name, address, city, totalUnits, occupiedUnits` | Backend has `province, postalCode, description, properties` extra |
| `UnitItem` | `units` | `id, buildingId, label, rentCents, status, bedrooms, bathrooms, squareFeet` | Backend stores rent as cents; returns `rent` (dollars) as computed field |
| `LeadItem` | `leads` | `id, fullName, email, phone, budgetCents, desiredUnit, source, stage, notes, tags` | Backend adds `language, assignedEmployeeId, buildingId, unitId` |
| `VisitItem` | `visits` | `id, unitId, employeeId, leadId, dateTime, durationMinutes, status, notes` | Backend adds `tenantConfirmed, employeeConfirmed, morningOfSent, outcome` |
| `StatCard` | *computed* | — | No direct table; assembled from analytics |
| `ActivityItem` | *computed* | — | No direct table; derived from communication logs / events |
| `OfferItem` | *missing* | — | ⚠️ No backend table for offers; only in Flutter model |
| `AlertItem` | *missing* | — | ⚠️ No backend table for alerts |

### Stage Enum Alignment

Stages are aligned — both Flutter and backend accept the same values. The backend accepts both camelCase (Flutter convention) and snake_case variants for backward compatibility.

| Flutter `LeadStage` | Backend `leads.stage` | Status |
|---------------------|-----------------------|--------|
| `nouveau` | `nouveau` | ✅ Match |
| `contacte` | `contacte` | ✅ Match |
| `qualifie` | `qualifie` | ✅ Match |
| `visitePlanifiee` | `visitePlanifiee`, `visite_planifiee` | ✅ Match (both accepted) |
| `offreEnvoyee` | `offreEnvoyee` | ✅ Match |
| `negociation` | `negociation` | ✅ Match |
| `bailSigne` | `bailSigne`, `signe` | ✅ Match (both accepted) |
| — | `visite_completee` | Backend-only (SMS flow) |
| — | `interesse` | Backend-only (SMS flow) |
| — | `inactif` | Backend-only (SMS flow) |

**Resolved.** Source of truth: `services/api-backend/src/constants/lead-stages.js` (backend), `lib/models.dart` `LeadStage` enum (Flutter). Flutter deserializes via `_snakeToCamel()` helper.

### Visit Status Mapping

| Flutter Display | Backend `visits.status` |
|-----------------|------------------------|
| `Confirmée` | `confirmed` |
| `Potentielle` | `scheduled` |

---

## 3. Screen-by-Screen Wiring Plan

### 3.1 HomeScreen (Accueil)

**Navigation shell** — contains `_HomeTab` as the first tab + 4 other screens.

#### _HomeTab Data Display

| UI Element | Current Source | Target API | Method |
|------------|---------------|------------|--------|
| User greeting ("Bonjour Simon") | Hardcoded | `GET /api/auth/profile` | Get user's `firstName` |
| Occupation badge (93.8%) | Hardcoded `StatCard` | `GET /api/analytics/dashboard` | `pipeline` or `weeklyStats` field |
| Quick stat cards (4×) | `stats` from demo_data | `GET /api/analytics/dashboard` | Multiple fields from dashboard response |
| Activity feed (4 items) | `activityFeed` from demo_data | `GET /api/communications?limit=5` + `GET /api/analytics/dashboard` | Communication logs + derived events |

#### API Endpoints Needed

| # | Endpoint | Purpose | When Called |
|---|----------|---------|-------------|
| 1 | `GET /api/auth/profile` | Fetch current user name for greeting | On init |
| 2 | `GET /api/analytics/dashboard` | Fetch all dashboard metrics (pipeline, weeklyStats, visitStats, conversionRates, leadSources) | On init |
| 3 | `GET /api/communications?limit=5` | Fetch recent activity feed | On init |

#### CRUD Actions

| Action | Endpoint | Trigger |
|--------|----------|---------|
| **Read** user profile | `GET /api/auth/profile` | Screen init |
| **Read** dashboard stats | `GET /api/analytics/dashboard` | Screen init |
| **Read** activity feed | `GET /api/communications?limit=5` | Screen init |
| Notifications (TODO) | No endpoint yet | IconButton tap (currently empty) |
| Settings (TODO) | No endpoint yet | IconButton tap (currently empty) |

#### Data Transformations Required

```
Dashboard API response:
{
  pipeline: { stages: [...], total, byStage: {...} },
  hotLeads: [...],
  weeklyStats: { ... },
  visitStats: { total, completed, cancelled, noShow, rate },
  conversionRates: { ... },
  leadSources: { ... }
}

→ Map to StatCard widgets:
  - Occupation rate → compute from buildings data or pipeline
  - Monthly revenue → from weeklyStats or dedicated endpoint
  - Active leads → pipeline.total
  - Weekly visits → visitStats.total
```

---

### 3.2 DashboardScreen (Tableau de bord)

#### Data Display

| UI Element | Current Source | Target API | Method |
|------------|---------------|------------|--------|
| Period selector ("Mars 2024") | Hardcoded | Client-side date picker | Query param `?period=2024-03` |
| Revenue chart placeholder | Static placeholder | `GET /api/analytics/dashboard` | Time-series revenue data |
| Performance metric cards (4×) | Hardcoded values | `GET /api/analytics/dashboard` | `weeklyStats` / computed |
| Top buildings list | `buildingItems` from demo_data | `GET /api/buildings?sortBy=name&limit=5` + `GET /api/analytics/buildings/:id/performance` | Paginated list + per-building analytics |

#### API Endpoints Needed

| # | Endpoint | Purpose | Query Params |
|---|----------|---------|-------------|
| 1 | `GET /api/analytics/dashboard` | Overall dashboard metrics | `?period=week\|month` |
| 2 | `GET /api/buildings?limit=10&sortBy=name` | Building list for "Meilleurs immeubles" | `?page=1&limit=10` |
| 3 | `GET /api/analytics/buildings/:id/performance` | Per-building occupancy & revenue | — |
| 4 | `GET /api/analytics/weekly-summary` | Weekly summary data | — |

#### CRUD Actions

| Action | Endpoint | Trigger |
|--------|----------|---------|
| **Read** dashboard overview | `GET /api/analytics/dashboard` | Screen init |
| **Read** building list | `GET /api/buildings` | Screen init |
| **Read** building performance | `GET /api/analytics/buildings/:id/performance` | Per building card |
| Period change (TODO) | Same endpoint with different params | Date picker tap (currently empty) |

#### Data Transformations Required

```
Building API → BuildingItem:
  building.name → name
  building.address → address
  building.totalUnits → totalUnits
  building.occupiedUnits → occupiedUnits
  building performance → occupancyRate, monthlyRevenue (computed or from analytics)
  
Note: Backend BuildingItem does NOT include monthlyRevenue directly.
Need to either:
  a) Add monthlyRevenue to buildings table, or
  b) Compute from units: SUM(rentCents) of occupied units / 100
```

---

### 3.3 PipelineScreen

#### Data Display

| UI Element | Current Source | Target API |
|------------|---------------|------------|
| 7 stage tabs (Nouveau → Signé) | Hardcoded `TabController` | `GET /api/leads?stage=<stage>` per tab |
| Stage header with count | Computed from `leadItems` | Response `metadata.total` per stage query |
| Lead cards (fullName, email, phone, desiredUnit, budget, notes, tags) | `leadItems` from demo_data | `GET /api/leads?stage=<stage>` |
| Stage badge on each card | `lead.stage` | `lead.stage` from API |

#### API Endpoints Needed

| # | Endpoint | Purpose | Query Params |
|---|----------|---------|-------------|
| 1 | `GET /api/leads?stage=nouveau` | Leads in "Nouveau" tab | `?page=1&limit=50&stage=nouveau` |
| 2 | `GET /api/leads?stage=contacte` | Leads in "Contacté" tab | `?stage=contacte` |
| 3 | `GET /api/leads?stage=qualifie` | Leads in "Qualifié" tab | `?stage=qualifie` |
| 4 | `GET /api/leads?stage=visitePlanifiee` | Leads in "Visite" tab | `?stage=visitePlanifiee` |
| 5 | `GET /api/leads?stage=offreEnvoyee` | Leads in "Offre" tab | `?stage=offreEnvoyee` |
| 6 | `GET /api/leads?stage=negociation` | Leads in "Négociation" tab | `?stage=negociation` |
| 7 | `GET /api/leads?stage=bailSigne` | Leads in "Bail signé" tab | `?stage=bailSigne` |
| 8 | `GET /api/analytics/leads/pipeline` | Pipeline summary with counts per stage | — |
| 9 | `GET /api/analytics/leads/hot` | Hot leads list | — |

**Alternative (efficient):** Fetch all leads once with `GET /api/leads?limit=200` and filter client-side by stage, OR use the pipeline analytics endpoint for counts + individual stage queries on tab switch.

#### CRUD Actions

| Action | Endpoint | Trigger |
|--------|----------|---------|
| **Read** leads by stage | `GET /api/leads?stage=<stage>` | Tab switch |
| **Read** pipeline summary | `GET /api/analytics/leads/pipeline` | Screen init (stage counts) |
| **Create** lead | `POST /api/leads` | "Ajouter un prospect" button |
| **Update** lead stage | `PATCH /api/leads/:id/status` | Drag between stages / stage advance |
| **Update** lead details | `PUT /api/leads/:id` | Edit lead card |
| **Delete** lead | `DELETE /api/leads/:id` | Delete action (not yet in UI) |
| **Bulk update** leads | `POST /api/leads/bulk` | Batch stage change |

#### Create Lead Payload

```json
POST /api/leads
{
  "fullName": "Émilie Beaudoin",
  "email": "emilie@email.com",
  "phone": "514-555-0123",
  "budgetCents": 160000,   // $1,600 in cents
  "desiredUnit": "3 1/2 - Rue Sherbrooke",
  "source": "fb",
  "stage": "nouveau",
  "notes": "Intéressée...",
  "tags": ["très chaud", "professionnel"],
  "language": "fr"
}
```

#### Stage Change Payload

```json
PATCH /api/leads/:id/status
{
  "stage": "contacte"
}
```

---

### 3.4 VisitsScreen

#### Data Display

| UI Element | Current Source | Target API |
|------------|---------------|------------|
| Date selector (← today →) | `DateTime _selectedDate` | Client-side state; used as query param |
| Stats summary (3 cards: total, confirmed, potential) | Hardcoded values | `GET /api/analytics/visits/stats?period=day` |
| Visit cards (time, status, building, unit, agent, notes) | Hardcoded `List<VisitItem>` | `GET /api/visits?dateFrom=...&dateTo=...` |
| "Détails" button | Empty `onPressed` | `GET /api/visits/:id` → detail view |
| "Confirmer" button | Empty `onPressed` | `PATCH /api/visits/:id/status` with `{ "status": "confirmed" }` |
| "+" button (AppBar) | Empty `onPressed` | `POST /api/visits` → create visit form |

#### API Endpoints Needed

| # | Endpoint | Purpose | Query Params |
|---|----------|---------|-------------|
| 1 | `GET /api/visits?dateFrom=<date>&dateTo=<date>&sortBy=dateTime&sortOrder=asc` | Visits for selected date | ISO date range |
| 2 | `GET /api/analytics/visits/stats?period=day` | Day's visit statistics | — |
| 3 | `GET /api/visits/:id` | Visit detail | — |
| 4 | `PATCH /api/visits/:id/status` | Confirm visit | Body: `{"status":"confirmed"}` |
| 5 | `POST /api/visits` | Create new visit | — |
| 6 | `PUT /api/visits/:id` | Update visit details | — |
| 7 | `DELETE /api/visits/:id` | Cancel/delete visit | — |

#### CRUD Actions

| Action | Endpoint | Trigger |
|--------|----------|---------|
| **Read** visits by date | `GET /api/visits?dateFrom=...&dateTo=...` | Date change |
| **Read** visit stats | `GET /api/analytics/visits/stats` | Date change |
| **Read** visit detail | `GET /api/visits/:id` | "Détails" tap |
| **Create** visit | `POST /api/visits` | "+" button |
| **Update** visit status (confirm) | `PATCH /api/visits/:id/status` | "Confirmer" tap |
| **Update** visit | `PUT /api/visits/:id` | Edit visit |
| **Delete** visit | `DELETE /api/visits/:id` | Cancel visit |

#### Create Visit Payload

```json
POST /api/visits
{
  "unitId": "uuid",
  "employeeId": "uuid",
  "leadId": "uuid",
  "dateTime": "2024-03-15T10:00:00.000Z",
  "durationMinutes": 30,
  "status": "scheduled",
  "notes": "Alexandre Martin - vue téléphone"
}
```

#### Data Transformations Required

```
Visit API response → VisitItem display:
  visit.dateTime → dateLabel (format HH:mm)
  visit.status → status (map: scheduled→"Potentielle", confirmed→"Confirmée")
  Need JOINs or include: unit.label, building.name, employee.fullName
  ⚠️ Backend returns IDs only — need population or separate lookups
  
Solution options:
  a) Add ?expand=unit,building,employee query param to backend
  b) Fetch related resources separately
  c) Backend already returns flat rows — verify if JOINs are done
```

---

### 3.5 BuildingsScreen (Immeubles)

#### Data Display

| UI Element | Current Source | Target API |
|------------|---------------|------------|
| Search bar | Non-functional placeholder | `GET /api/buildings?search=<query>` |
| Building cards (name, address, occupancy rate, revenue, units) | `buildingItems` from demo_data | `GET /api/buildings` |
| Occupancy progress bar | Computed `occupancyRate` | Computed from `occupiedUnits / totalUnits` |
| "Voir détails" button | Empty `onPressed` | `GET /api/buildings/:id` + `GET /api/buildings/units?buildingId=:id` |
| "Gérer" button | Empty `onPressed` | Navigate to building detail/manage screen |
| "+" button (AppBar) | Empty `onPressed` | `POST /api/buildings` → create form |

#### API Endpoints Needed

| # | Endpoint | Purpose | Query Params |
|---|----------|---------|-------------|
| 1 | `GET /api/buildings?sortBy=name` | List all buildings | `?search=<query>&page=1&limit=20` |
| 2 | `GET /api/buildings/:id` | Building detail | — |
| 3 | `GET /api/buildings/units?buildingId=:id` | Units for a building | `?buildingId=uuid` |
| 4 | `POST /api/buildings` | Create building | — |
| 5 | `PUT /api/buildings/:id` | Update building | — |
| 6 | `DELETE /api/buildings/:id` | Delete building (soft) | — |
| 7 | `POST /api/buildings/units` | Add unit to building | — |
| 8 | `PUT /api/buildings/units/:id` | Update unit | — |
| 9 | `DELETE /api/buildings/units/:id` | Delete unit (soft) | — |
| 10 | `GET /api/employees/building/:buildingId` | Get agents assigned to building | — |
| 11 | `GET /api/analytics/buildings/:id/performance` | Building performance metrics | — |

#### CRUD Actions

| Action | Endpoint | Trigger |
|--------|----------|---------|
| **Read** buildings (list) | `GET /api/buildings?search=<q>` | Screen init / search |
| **Read** building detail | `GET /api/buildings/:id` | "Voir détails" tap |
| **Read** units for building | `GET /api/buildings/units?buildingId=:id` | Building detail |
| **Create** building | `POST /api/buildings` | "+" button |
| **Update** building | `PUT /api/buildings/:id` | "Gérer" → edit |
| **Delete** building | `DELETE /api/buildings/:id` | "Gérer" → delete |
| **Create** unit | `POST /api/buildings/units` | Add unit in manage view |
| **Update** unit | `PUT /api/buildings/units/:id` | Edit unit |
| **Delete** unit | `DELETE /api/buildings/units/:id` | Remove unit |

#### Create Building Payload

```json
POST /api/buildings
{
  "name": "Le Saint-Laurent",
  "address": "305 Rue Sherbrooke Ouest",
  "city": "Montréal",
  "province": "QC",
  "postalCode": "H3H 1X1",
  "totalUnits": 24,
  "occupiedUnits": 0,
  "properties": { "description": "..." }
}
```

#### Create Unit Payload

```json
POST /api/buildings/units
{
  "buildingId": "uuid",
  "label": "302",
  "rent": 1850,
  "status": "vacant",
  "bedrooms": 2,
  "bathrooms": 1,
  "squareFeet": 1200,
  "type": "4 1/2"
}
```

---

## 4. Cross-Cutting Concerns

### Authentication Flow

```
App Launch → Check stored tokens
  ├─ Valid accessToken → Proceed to HomeScreen
  ├─ Expired accessToken + valid refreshToken → POST /api/auth/refresh → new tokens → proceed
  └─ No valid tokens → LoginScreen
       ├─ POST /api/auth/login → store tokens → HomeScreen
       └─ POST /api/auth/register → store tokens → HomeScreen
```

**Endpoints:**
| Action | Endpoint | Notes |
|--------|----------|-------|
| Login | `POST /api/auth/login` | Body: `{ email, password }` → `{ user, tokens }` |
| Register | `POST /api/auth/register` | Body: `{ email, password, firstName, lastName }` → `{ user, tokens }` |
| Refresh | `POST /api/auth/refresh` | Body: `{ refreshToken }` → `{ tokens }` |
| Logout | `POST /api/auth/logout` | Body: `{ refreshToken }` |
| Get profile | `GET /api/auth/profile` | Headers: `Authorization: Bearer <token>` |
| Update profile | `PUT /api/auth/profile` | Body: `{ firstName, lastName, email }` |
| Change password | `PUT /api/auth/password` | Body: `{ currentPassword, newPassword }` |

### Standard API Response Format

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation successful",
  "metadata": {
    "total": 42,
    "page": 1,
    "limit": 20,
    "totalPages": 3,
    "hasMore": true
  }
}
```

```json
// Error
{
  "success": false,
  "error": {
    "message": "Resource not found",
    "code": "BUILDING_NOT_FOUND"
  }
}
```

### All Endpoints Require

```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

### Pagination Pattern (all list endpoints)

```
GET /api/<resource>?page=1&limit=20&sortBy=createdAt&sortOrder=desc
```

### Soft Delete Pattern

All DELETE endpoints perform soft deletes (`isActive = false`). Data is never permanently removed.

---

## 5. Gaps & Recommendations

### 🔴 Critical Gaps

| # | Issue | Impact | Recommendation |
|---|-------|--------|----------------|
| 1 | **Lead stage enum mismatch** | Pipeline screen cannot filter correctly | Align `LeadStage` enum: Flutter uses `qualifie, offreEnvoyee, negociation, bailSigne` vs backend's `visite_completee, interesse, signe, inactif`. Must decide canonical set. |
| 2 | **No `monthlyRevenue` on buildings** | Dashboard & Buildings screen can't show revenue | Add `monthlyRevenueCents` column to buildings table, or compute from units at query time. |
| 3 | **Visits return IDs only** | Can't display building name, unit label, agent name | Backend needs to JOIN/populate `visits` with `units.label`, `buildings.name`, `employees.firstName/lastName`, `leads.fullName`. Add `?expand=` or always include. |
| 4 | **No OfferItem backend table** | Pipeline shows offers but no CRUD | Either create `offers` table with CRUD endpoints, or remove from Flutter model. |
| 5 | **No Activity feed endpoint** | Home screen can't show real activity | Create a dedicated activity/events endpoint that aggregates from communications, visits, lease changes. |

### 🟡 Medium Priority

| # | Issue | Impact | Recommendation |
|---|-------|--------|----------------|
| 6 | **No notification endpoint** | Bell icon does nothing | Create `/api/notifications` with real-time push (WebSocket/FCM). |
| 7 | **Buildings search not wired** | Search bar is cosmetic | Wire search input to `GET /api/buildings?search=<query>`. |
| 8 | **Revenue chart is placeholder** | Dashboard has no chart data | `GET /api/analytics/dashboard` needs time-series revenue data. Consider monthly breakdown. |
| 9 | **Period selector not functional** | Dashboard period is hardcoded | Add `?period=month&date=2024-03` query params to analytics endpoints. |
| 10 | **Flutter `budget` is int (dollars)** | Backend `budgetCents` is cents | Convert: Flutter `budget` 1600 → backend `budgetCents` 160000. |

### 🟢 Nice to Have

| # | Issue | Impact | Recommendation |
|---|-------|--------|----------------|
| 11 | No real-time updates | User must refresh | Add WebSocket or polling for visit confirmations, new leads. |
| 12 | No offline support | App requires connectivity | Add local SQLite cache with sync. |
| 13 | No image upload for buildings | Building cards show placeholder | Wire image upload to `/api/documents` with `referenceType: 'building'`. |

---

## Implementation Priority Matrix

| Phase | Screens | Endpoints | Effort |
|-------|---------|-----------|--------|
| **Phase 1** | Auth flow (login/register) + HomeScreen | `auth/*`, `analytics/dashboard`, `communications` | High |
| **Phase 2** | BuildingsScreen + Units | `buildings/*`, `buildings/units/*` | Medium |
| **Phase 3** | PipelineScreen | `leads/*`, `analytics/leads/*` | High (stage enum fix) |
| **Phase 4** | VisitsScreen | `visits/*`, `analytics/visits/*` | Medium |
| **Phase 5** | DashboardScreen | `analytics/*` (full) | Medium |
| **Phase 6** | Settings, Notifications, Documents | `auth/profile`, `documents/*` | Low |

---

*Generated: 2026-04-08 | Source: ImmoGestion Flutter lib/ + api-backend/src/*
