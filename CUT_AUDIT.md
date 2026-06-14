# AUDIT DE COUPE — ImmoGestion v3 (RAPPORT)

> Rapport de décision uniquement — **rien n'est supprimé**. La suppression sera l'étape 3.
> Méthode : lecture de `schema.js` + 40 écrans + 23 services Flutter + 27 controllers + 21 services backend + 29 routes.

---

## ⚠️ DÉCISION CRITIQUE — Employés = Concierges (NE PAS supprimer la couche données)

Le brief liste « Employés (3 tables, 2 écrans) » dans SUPPRIME, mais le **pilier 1 exige « Concierges avec horaires »**. Dans le code, **concierge = `employees`**, et c'est porteur :

- `visits.employeeId` est **NOT NULL** → une visite ne peut exister sans concierge (pilier 1).
- `employee_schedules` = **les horaires des concierges** (pilier 1 littéral).
- `maintenance_command_center.service` lit employees/assignments/schedules pour la capacité (pilier 2).
- `renovation_tasks.assigneeEmployeeId` = assignation des tâches (pilier 3).

**Recommandation : GARDER** `employees`, `employee_assignments`, `employee_schedules` + leurs services/controllers (= infra « Concierges »). Au plus, *simplifier* l'UI RH plus tard. Classé **GARDE** ci-dessous, pas SUPPRIME. → décision à confirmer par Simon.

---

# Fichiers à SUPPRIMER

### Frontend (lib/)
- `lib/screens/marketplace_inbox_screen.dart` — ImmoCRM gère les leads
- `lib/screens/pipeline_screen.dart` — ImmoCRM a déjà un pipeline
- `lib/screens/conversation_detail_screen.dart` — thread email/appel (non-SMS)
- `lib/screens/documents_screen.dart` — doublon PlexFlow
- `lib/screens/document_preview_screen.dart` — doublon PlexFlow
- `lib/screens/dossier_assistant_screen.dart` — dossiers TAL, pas utilisé
- `lib/screens/onboarding_screen.dart` — onboarding, sert une fois
- `lib/screens/onboarding_building_step.dart` — onboarding, sert une fois
- `lib/screens/onboarding_units_step.dart` — onboarding, sert une fois
- `lib/screens/onboarding_invite_step.dart` — onboarding, sert une fois
- `lib/screens/public_entry_screen.dart` — page publique/démo
- `lib/screens/daily_task_tracker_screen.dart` — tracker hors piliers
- `lib/screens/observation_review_inbox_screen.dart` — placeholder QA inutilisé
- `lib/screens/tenant_checklist_operator_screen.dart` — checklist hors piliers
- `lib/services/document_service.dart` — doublon PlexFlow
- `lib/services/tenant_checklist_service.dart` — checklist hors piliers
- `lib/services/demo_mode.dart` — mode démo/public

### Backend (services/api-backend/src/)
**Controllers**
- `controllers/twilio-whatsapp.controller.js` — WhatsApp over-engineered
- `controllers/facebook-webhook.controller.js` — Messenger / Lead Ads
- `controllers/document.controller.js` — doublon PlexFlow
- `controllers/dossier.controller.js` — dossiers TAL inutilisés
- `controllers/observation-result.controller.js` — QA inbox inutilisé
- `controllers/tenant-checklist.controller.js` — checklist hors piliers
- `controllers/admin.controller.js` — seed/clear démo
- `controllers/demo.controller.js` — login démo

**Services**
- `services/whatsapp.service.js` — WhatsApp over-engineered
- `services/conversation-router.service.js` — routage WhatsApp uniquement
- `services/messenger-bot.service.js` — bot Messenger
- `services/facebook.service.js` — API Facebook/Lead Ads
- `services/dossier.service.js` — dossiers TAL
- `services/dossier-assembly.service.js` — wrapper dossiers TAL
- `services/tenant-checklist.service.js` — checklist hors piliers
- `services/marketplace-mode.js` — détection mode démo/marketplace
- `services/email.service.js` — email (SMS seulement) *(voir note 1)*
- `services/weekly-report.service.js` — digest email hebdo *(voir note 1)*

**Routes**
- `routes/twilio-whatsapp.routes.js` — WhatsApp
- `routes/facebook.routes.js` — Messenger / Lead Ads
- `routes/document.routes.js` — doublon PlexFlow
- `routes/dossier.routes.js` — dossiers TAL
- `routes/observation-result.routes.js` — QA inbox inutilisé
- `routes/tenant-checklist.routes.js` — checklist hors piliers
- `routes/marketplace.routes.js` — ImmoCRM gère les leads
- `routes/admin.routes.js` — seed/clear démo
- `routes/demo.routes.js` — login démo

> Note 1 — `email.service` / `weekly-report` / `notification.service` : tout l'email tombe sous « SMS seulement ». `email.service` + `weekly-report` → SUPPRIME. `notification.service` envoie aussi des alertes email mais est appelé par `renewal.controller` → classé **SIMPLIFIE** (convertir en SMS ou retirer), pas supprimé sec, pour ne pas casser les renouvellements.

### Tables DB à dropper
- `whatsapp_conversations` — WhatsApp supprimé
- `messenger_conversations` — Messenger supprimé
- `documents` — doublon PlexFlow
- `documents_leads` — junction documents
- `dossier_cases` — dossiers TAL
- `dossier_case_items` — dossiers TAL
- `tenant_checklist_sessions` — checklist supprimée
- `tenant_checklist_steps` — checklist supprimée
- `tenant_checklist_attachments` — checklist supprimée
- `tenant_checklist_signatures` — checklist supprimée
- `tenant_checklist_events` — checklist supprimée
- `observation_results` — QA inbox inutilisé

> **NON droppées** malgré le brief : `employees`, `employee_assignments`, `employee_schedules` (= concierges, voir décision critique).
> Le brief disait « Dossiers TAL (8 tables) » → il n'y en a que **2** (`dossier_cases`, `dossier_case_items`). Les autres tables suspectées sont en fait les 5 tables `tenant_checklist_*` + `observation_results`, listées séparément ci-dessus.

### Migration à créer (DROP TABLE)
`services/api-backend/migrations/drop_unused_modules.sql` — drops en ordre FK-safe (CASCADE) :

```sql
BEGIN;
-- TAL dossiers
DROP TABLE IF EXISTS dossier_case_items CASCADE;
DROP TABLE IF EXISTS dossier_cases CASCADE;
-- Tenant checklist
DROP TABLE IF EXISTS tenant_checklist_events CASCADE;
DROP TABLE IF EXISTS tenant_checklist_attachments CASCADE;
DROP TABLE IF EXISTS tenant_checklist_signatures CASCADE;
DROP TABLE IF EXISTS tenant_checklist_steps CASCADE;
DROP TABLE IF EXISTS tenant_checklist_sessions CASCADE;
-- Documents (doublon PlexFlow)
DROP TABLE IF EXISTS documents_leads CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
-- Canaux supprimés
DROP TABLE IF EXISTS whatsapp_conversations CASCADE;
DROP TABLE IF EXISTS messenger_conversations CASCADE;
-- QA inbox
DROP TABLE IF EXISTS observation_results CASCADE;
COMMIT;
```
> Retirer aussi ces tables de `src/database/schema.js` (définitions + `module.exports`) après le drop.

---

# Fichiers à GARDER

### Frontend — Auth
- `lib/screens/login_screen.dart` — auth
- `lib/screens/register_screen.dart` — auth (admin)
- `lib/screens/auth_desktop_layout.dart` — layout auth
- `lib/services/auth_service.dart` — état auth
- `lib/services/api_service.dart` — client HTTP/JWT (socle)
- `lib/services/auth_token_storage.dart` / `_stub.dart` / `_web.dart` — persistance token

### Frontend — Parc immobilier (lecture PlexFlow)
- `lib/screens/buildings_screen.dart` — immeubles
- `lib/screens/units_screen.dart` — unités
- `lib/screens/unit_detail_screen.dart` — détail unité
- `lib/services/building_service.dart` — immeubles
- `lib/services/unit_service.dart` — unités
- `lib/services/cache_service.dart` — cache TTL (socle)

### Frontend — Baux & Paiements (sync PlexFlow)
- `lib/screens/leases_screen.dart` — baux
- `lib/screens/lease_detail_screen.dart` — détail bail
- `lib/screens/lease_form_screen.dart` — formulaire bail
- `lib/screens/payments_screen.dart` — paiements
- `lib/screens/payment_detail_screen.dart` — détail paiement
- `lib/services/lease_service.dart` — baux
- `lib/services/payment_service.dart` — paiements

### Frontend — Pilier 1 Leasing (leads, visites, calendrier, concierges, SMS)
- `lib/screens/lead_detail_screen.dart` — leads (détail)
- `lib/screens/visits_screen.dart` — visites
- `lib/screens/visit_detail_screen.dart` — détail visite
- `lib/screens/visit_form_screen.dart` — planif visite
- `lib/screens/calendar_screen.dart` — calendrier
- `lib/screens/compose_sms_screen.dart` — composition SMS
- `lib/screens/sms_conversation_screen.dart` — fil SMS
- `lib/screens/employees_screen.dart` — concierges *(décision critique)*
- `lib/screens/employee_detail_screen.dart` — horaires concierge *(décision critique)*
- `lib/services/lead_service.dart` — leads
- `lib/services/visit_service.dart` — visites
- `lib/services/employee_service.dart` — concierges *(décision critique)*
- `lib/services/schedule_service.dart` — horaires concierges *(décision critique)*

### Frontend — Pilier 2 Maintenance / Pilier 3 Rénovation
- `lib/screens/maintenance_command_center_screen.dart` — pilier maintenance
- `lib/screens/renovation_ops_screen.dart` — pilier rénovation
- `lib/services/maintenance_service.dart` — maintenance
- `lib/services/property_photo_service.dart` — photos rénovation

### Frontend — Transverse
- `lib/services/analytics_service.dart` — KPI dashboard
- `lib/services/activity_service.dart` — fil d'activité dashboard
- `lib/services/notification_preferences_service.dart` — préfs (settings)
- `lib/screens/home_screen.dart` — shell nav *(à SIMPLIFIER)*
- `lib/screens/dashboard_screen.dart` — dashboard *(à SIMPLIFIER)*
- `lib/screens/settings_screen.dart` — settings *(à SIMPLIFIER)*
- `lib/screens/communications_screen.dart` — comms *(à SIMPLIFIER → SMS)*
- `lib/services/communication_service.dart` — comms *(à SIMPLIFIER → SMS)*

### Backend — Controllers
- `controllers/auth.controller.js` — auth/JWT
- `controllers/building.controller.js` — immeubles/unités
- `controllers/lease.controller.js` — baux
- `controllers/payment.controller.js` — paiements
- `controllers/renewal.controller.js` — renouvellement bail (leasing)
- `controllers/lead.controller.js` — leads
- `controllers/visit.controller.js` — visites
- `controllers/tenant-confirmation.controller.js` — confirmation visite (SMS)
- `controllers/employee.controller.js` — concierges *(décision critique)*
- `controllers/schedule.controller.js` — horaires concierges *(décision critique)*
- `controllers/sms-webhook.controller.js` — SMS entrants Twilio
- `controllers/sms-campaign.controller.js` — templates/campagnes SMS
- `controllers/maintenance.controller.js` — pilier maintenance
- `controllers/renovation.controller.js` — pilier rénovation
- `controllers/renovation-job-template.controller.js` — gabarits matériaux
- `controllers/photo.controller.js` — photos rénovation
- `controllers/analytics.controller.js` — KPI dashboard
- `controllers/notification.controller.js` — préfs/in-app *(SIMPLIFIE l'email)*
- `controllers/communication.controller.js` — comms *(à SIMPLIFIER → SMS)*

### Backend — Services
- `services/sms.service.js` — SMS (cœur piliers 1+2)
- `services/twilio.service.js` — client Twilio
- `services/scheduler.service.js` — cron rappels SMS/paiements
- `services/analytics.service.js` — KPI dashboard
- `services/maintenance-command-center.service.js` — pilier maintenance
- `services/renovation-readiness.service.js` — état rénovation→leasing
- `services/issue-queue-state.js` — file maintenance
- `services/photo.service.js` — photos rénovation
- `services/photo-storage.service.js` — stockage photos
- `services/communication-thread.service.js` — fils SMS *(SIMPLIFIE: retirer marketplace-mode)*
- `services/notification.service.js` — alertes *(SIMPLIFIE → SMS, voir note 1)*

### Backend — Routes
- `routes/index.js` — agrégateur *(à SIMPLIFIER: retirer les mounts supprimés)*
- `routes/auth.routes.js` — auth
- `routes/building.routes.js` — immeubles/unités
- `routes/lease.routes.js` — baux
- `routes/payment.routes.js` — paiements
- `routes/renewal.routes.js` — renouvellement
- `routes/lead.routes.js` — leads
- `routes/visit.routes.js` — visites
- `routes/tenant-confirmation.routes.js` — confirmation visite
- `routes/employee.routes.js` — concierges *(décision critique)*
- `routes/schedule.routes.js` — horaires concierges *(décision critique)*
- `routes/sms.routes.js` — webhook SMS Twilio
- `routes/sms-campaign.routes.js` — templates/campagnes SMS
- `routes/maintenance.routes.js` — pilier maintenance
- `routes/renovation.routes.js` — pilier rénovation
- `routes/renovation-job-template.routes.js` — gabarits matériaux
- `routes/photo.routes.js` — photos rénovation
- `routes/analytics.routes.js` — KPI dashboard
- `routes/notification.routes.js` — notifications/préfs
- `routes/communication.routes.js` — comms *(à SIMPLIFIER → SMS)*

### Tables DB à GARDER
`users`, `refresh_tokens`, `buildings`, `units`, `leases`, `payments`, `renewal_offers`, `leads`, `visits`, `sms_logs`, `communication_threads`, `communication_logs` *(simplifier → SMS)*, `sms_templates`, `sms_campaigns`, `sms_queue`, `sms_opt_outs`, `notifications`, `notification_preferences`, `property_photos`, `renovations`, `renovation_tasks`, `renovation_orders`, `renovation_receiving_events`, `renovation_surplus_items`, `renovation_job_templates`, `worker_intake_records`, `unit_readiness`, **`employees`, `employee_assignments`, `employee_schedules`** *(concierges — décision critique)*.

---

# Fichiers à SIMPLIFIER

- `lib/screens/communications_screen.dart` → SMS seulement (retirer onglets email/appel)
- `lib/services/communication_service.dart` → SMS seulement (retirer méthodes marketplace inbox / email / call)
- `controllers/communication.controller.js` → retirer marketplace inbox + logs email/appel ; garder fils SMS + activité
- `services/communication-thread.service.js` → retirer la dépendance à `marketplace-mode.js` (supprimé)
- `services/notification.service.js` → convertir alertes email en SMS (ou retirer) ; appelé par `renewal.controller`
- `controllers/notification.controller.js` → garder préfs + in-app ; retirer envoi email
- `lib/screens/dashboard_screen.dart` → refonte 3 piliers ; retirer la réf à `OnboardingScreen` (supprimé)
- `lib/screens/home_screen.dart` → retirer du nav : Marketplace, Pipeline, Documents, Employés(→Concierges), Daily tasks, Observations, Dossier, Onboarding, Checklist
- `lib/screens/settings_screen.dart` → réduire à l'essentiel
- `routes/index.js` → retirer mounts : `/webhooks/facebook`, `/webhooks/twilio/whatsapp`, `/marketplace`, `/documents`, `/admin`, `/demo`, `/companies/:companyId/dossiers`, `/companies/:companyId/tenant-checklists`, `/companies/:companyId/observation-results`

---

# Dépendances à recâbler après suppression (à traiter à l'étape 3)

1. `dashboard_screen.dart` & `home_screen.dart` importent/poussent des écrans supprimés (Onboarding, Pipeline, Marketplace) → retirer imports + navigation.
2. `lead_detail_screen.dart` était poussé depuis `pipeline_screen` et `marketplace_inbox` (supprimés) → garder l'écran mais lui donner un autre point d'entrée (ex. liste leads ou fil SMS).
3. `communication-thread.service.js` importe `marketplace-mode.js` (supprimé) → retirer l'import.
4. `messenger-bot.service.js` (supprimé) importait `visit.controller`/`sms.service` — pas d'impact inverse (ceux-ci restent).
5. `renewal.controller.js` importe `notification.service` → garder le service ou basculer en SMS (note 1).
6. `index.js` : retirer les `require()` des routes supprimées en plus des `.use()`.
7. `schema.js` : retirer les 12 définitions de tables droppées + leurs entrées dans `module.exports`.
8. Garder `constants/marketplace-states.js` (≠ `marketplace-mode.js`) : utilisé par `leads.qualificationState` et `communication_threads.bookingState` (travail IMM-723 récent).

---

# Récapitulatif chiffré

| Catégorie | Frontend | Backend (ctrl/svc/routes) | Tables |
|---|---|---|---|
| **SUPPRIME** | 14 écrans + 3 services = 17 | 8 ctrl + 10 svc + 9 routes = 27 | 12 |
| **SIMPLIFIE** | 5 | 5 | 1 (`communication_logs`) |
| **GARDE** | ~22 | ~46 | ~31 (dont 3 concierges en décision) |

**Décision en attente de Simon** : confirmer le maintien de la couche **Concierges** (`employees` ×3 tables + écrans/services associés), nécessaire aux 3 piliers malgré la mention « Employés » dans SUPPRIME.
