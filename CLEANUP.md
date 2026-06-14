# ÉTAPE 3 — Nettoyage ImmoGestion v3

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/. Tu viens de faire l'audit de coupe (CUT_AUDIT.md). Maintenant tu EXÉCUTES la suppression de tous les modules non essentiels.

## Règles absolues
- **Ne supprime rien** sans l'avoir lu d'abord
- **Vérifie les dépendances** avant de supprimer un fichier — si un fichier gardé importe un fichier supprimé, adapte le fichier gardé
- **Backend :** `npm run lint` après chaque batch de suppressions
- **Frontend :** `flutter analyze` après chaque batch
- **Migration DB :** applique `drop_unused_modules.sql` (déjà préparé dans l'audit de coupe)
- **Pas de commentaires** dans le code
- **Langue :** français québécois pour les strings, anglais pour le code

## Modules à SUPPRIMER

### Frontend (lib/screens/)
Supprime ces fichiers :
- `marketplace_inbox_screen.dart` — ImmoCRM gère les leads
- `pipeline_screen.dart` — ImmoCRM a déjà un pipeline
- `public_entry_screen.dart` — outil interne, pas public
- `daily_task_tracker_screen.dart` — non essentiel
- `observation_review_inbox_screen.dart` — non utilisé
- `tenant_checklist_operator_screen.dart` — non utilisé
- `dossier_assistant_screen.dart` — dossiers TAL non utilisés
- `onboarding_screen.dart` + `onboarding_building_step.dart` + `onboarding_invite_step.dart` + `onboarding_units_step.dart` — 4 écrans, sert une fois
- `documents_screen.dart` + `document_preview_screen.dart` — doublon PlexFlow
- `employees_screen.dart` + `employee_detail_screen.dart` — ⚠️ VÉRIFIER AVANT : dans le code, `employees` = concierges. Si c'est le cas, GARDE-LES. Sinon, supprime.

### Frontend (lib/services/)
Supprime ces fichiers :
- `communication_service.dart` — remplacer par SMS seulement (garde `sms_service.dart` si existe)
- `document_service.dart` — doublon PlexFlow
- `dossier_service.dart` — non utilisé
- `tenant_checklist_service.dart` — non utilisé
- `marketplace_service.dart` — ImmoCRM gère
- `pipeline_service.dart` — ImmoCRM gère
- `employee_service.dart` — ⚠️ VÉRIFIER : si employees = concierges, GARDE.

### Backend (services/api-backend/src/controllers/)
Supprime :
- `marketplace.controller.js` + routes associées
- `pipeline.controller.js` + routes associées
- `document.controller.js` + routes associées
- `dossier.controller.js` + routes associées
- `tenant_checklist.controller.js` + routes associées
- `employee.controller.js` — ⚠️ VÉRIFIER : si concierges, GARDE.
- `demo.controller.js` + `admin.controller.js`
- `onboarding.controller.js` + routes

### Backend (services/api-backend/src/services/)
Supprime :
- `whatsapp.service.js` — over-engineered
- `facebook.service.js` — pas utilisé
- `messenger-bot.service.js` — pas utilisé
- `email.service.js` — pas utilisé activement
- `weekly-report.service.js` — pas essentiel
- `document.service.js` — doublon
- `dossier.service.js` + `dossier-assembly.service.js` — non utilisé
- `tenant_checklist.service.js` — non utilisé
- `marketplace.service.js` — ImmoCRM gère
- `pipeline.service.js` — ImmoCRM gère

### Backend (services/api-backend/src/routes/)
Supprime les fichiers de routes correspondant aux contrôleurs supprimés.

### Backend (services/api-backend/src/middleware/)
Supprime :
- `marketplace-mode.js` — plus de marketplace
- `demoWriteGuard.js` — plus de démo (mais QW3 l'a branché, vérifie)

### Tables DB à dropper
Applique la migration `drop_unused_modules.sql` préparée dans l'audit de coupe. Tables :
- `whatsapp_conversations`, `messenger_conversations`
- `sms_campaigns`, `sms_queue`, `sms_templates`, `sms_opt_outs`
- `documents`, `documents_leads`
- `dossier_cases`, `dossier_case_items`
- `tenant_checklist_sessions`, `tenant_checklist_steps`, `tenant_checklist_attachments`, `tenant_checklist_signatures`, `tenant_checklist_events`
- `observation_results`
- `renovation_job_templates` (si pas dans migration existante)
- `notification_preferences`, `notifications` (si pas utilisées ailleurs)

### Fichiers de config
Supprime :
- `lib/app_config.dart` — référence à DEMO_MODE? Si oui, nettoie.
- `lib/utils/demo_mode.dart` — plus de démo
- `lib/utils/entrypoint_policy.dart` — simplifie (plus de public landing)

## Modules à SIMPLIFIER (garde mais réduit)

### Communications → SMS seulement
- `lib/screens/communications_screen.dart` — vire WhatsApp/Messenger/Facebook, garde SMS
- `lib/screens/compose_sms_screen.dart` — garde
- `lib/screens/sms_conversation_screen.dart` — garde
- `lib/screens/conversation_detail_screen.dart` — simplifie (SMS seulement)
- Backend : garde `twilio.service.js`, `sms.service.js`, `communication.controller.js` (réduit à SMS)

### Dashboard → prépare pour refonte étape 4
- `lib/screens/dashboard_screen.dart` — GARDE (refonte étape 4)
- `lib/screens/home_screen.dart` — GARDE mais retire les liens vers écrans supprimés

### Settings → réduit
- `lib/screens/settings_screen.dart` — GARDE, retire les sections non utilisées

## Fichiers à GARDER (ne pas toucher)
- Auth : login_screen, register_screen, auth_service, auth_token_storage*
- Parc immobilier : buildings_screen, units_screen, unit_detail_screen, building_service
- Baux : leases_screen, lease_detail_screen, lease_form_screen
- Paiements : payments_screen, payment_detail_screen
- Leads : lead_detail_screen (simplifié pour leasing)
- Visites : visits_screen, visit_detail_screen, visit_form_screen
- Calendrier : calendar_screen
- Maintenance : maintenance_command_center_screen
- Rénovation : renovation_ops_screen
- Concierges : employees_screen, employee_detail_screen, employee_service, employee.controller (si employees = concierges)
- SMS : compose_sms_screen, sms_conversation_screen
- Dashboard : dashboard_screen, home_screen
- Settings : settings_screen
- Modèles : models.dart (garde, simplifie plus tard)
- Services backend correspondants aux fichiers gardés

## Vérification finale
1. `npm run lint` dans services/api-backend/ — doit passer
2. `flutter analyze` dans lib/ — doit passer
3. `npm test` dans services/api-backend/ — les tests des modules gardés doivent passer
4. Migration DB appliquée et vérifiée
5. Liste tout ce qui a été supprimé, gardé, simplifié
