# TASK — Voice AI Agent Flow + Maintenance par Bâtiment

Tu es un développeur senior full-stack (Node.js/Express/Drizzle/PostgreSQL + Flutter). Implémente le flow complet du Voice AI agent pour ImmoGestion.

## Contexte
ImmoGestion = SaaS gestion locative (61 portes, 7 immeubles, Sherbrooke QC). Le Voice AI permet aux locataires d'appeler pour signaler des problèmes → STT→LLM→TTS → ticket maintenance créé → notification → regroupé par bâtiment.

## Stack
Backend: Node.js/Express/Drizzle/PostgreSQL (services/api-backend/src/)
Frontend: Flutter Web Material 3 (lib/)
Voice: Twilio (SMS existant) + Deepgram STT + ElevenLabs TTS

## État actuel ✅
- `twilio.service.js` — SMS, validateTwilioWebhook
- `maintenance.service.js` — CRUD tickets, `ingestVapiWebhook`, `getOpenTicketCountByBuilding`
- `maintenance.controller.js` — endpoints REST + `receiveVapiWebhook`
- `maintenance-command-center.service.js` — tableau de bord (663 lignes)
- `notification.service.js` — service notifications existant
- `maintenance_command_center_screen.dart` — UI Flutter

## Ce que tu dois implémenter

### 1. Voice AI Pipeline (backend — 2 nouveaux fichiers)

**`services/api-backend/src/services/voice-ai.service.js`**
- `handleIncomingCall(callSid, from, to)` — appelé par le webhook Twilio
- Ouvre WebSocket Deepgram pour STT temps réel (utilise `ws` ou `http`)
- Accumule le transcript
- À la fin de l'appel → classifie via `classification.service.js` → crée ticket via `maintenanceService.createTicket()` → joue TTS ElevenLabs → notifie admins
- Fallback: si STT/LLM/TTS down → crée ticket basique (urgency=moyenne, source='voice_ai')

**`services/api-backend/src/services/classification.service.js`**
- `classifyMaintenanceRequest(transcript)` → appelle OpenAI/Claude avec prompt structuré
- Prompt: "Classifie cette demande de maintenance d'un locataire. Retourne UNIQUEMENT JSON: {urgency: basse|moyenne|haute|urgence, category: plomberie|électrique|chauffage|structure|autre, summary: résumé 1 phrase}"
- Fallback: si LLM down → urgency=moyenne, category=autre, summary=transcript.slice(0,200)

### 2. Controller + Routes (backend — 2 nouveaux fichiers)

**`services/api-backend/src/controllers/voice-ai.controller.js`**
- `handleIncomingCall` — valide Twilio webhook → délègue à voiceAiService
- `handleStatus` — log call status

**`services/api-backend/src/routes/voice.routes.js`**
- POST /webhooks/twilio/voice → validateTwilioWebhook → handleIncomingCall
- POST /webhooks/twilio/voice/status → handleStatus

### 3. Notification temps réel (backend — modifier 2 fichiers)

**Modifier `services/api-backend/src/services/notification.service.js`**
- Ajouter `notifyNewMaintenanceTicket(ticket)` — push notification aux admins (log + SSE endpoint si pas de push provider)

**Modifier `services/api-backend/src/services/maintenance.service.js`**
- Dans `createTicket()`, après création, si source === 'voice_ai' → `notificationService.notifyNewMaintenanceTicket(ticket)`

### 4. Regroupement par bâtiment (frontend — modifier 2 fichiers)

**Modifier `lib/services/maintenance_service.dart`**
- Ajouter `getOpenTicketCountByBuilding()` → GET /maintenance/tickets/open-count-by-building

**Modifier `lib/screens/maintenance_command_center_screen.dart`**
- Ajouter section "Tickets par bâtiment" AVANT le backlog existant
- Cartes par bâtiment: nom + compteur + barre urgence/haute/moyenne/basse + bouton "Voir"
- Utilise `getOpenTicketCountByBuilding()` (backend déjà existant)

### 5. Routes index (backend — modifier 1 fichier)

**Modifier `services/api-backend/src/routes/index.js`**
- Ajouter `app.use('/webhooks/twilio/voice', voiceRoutes)`

## Règles strictes
- Réutilise twilio.service.js (validateTwilioWebhook), maintenance.service.js (createTicket, getOpenTicketCountByBuilding), notification.service.js
- Pas de breaking changes sur les endpoints existants
- Utilise le logger existant (`require('../utils/logger')`)
- Fallbacks partout: si STT/LLM/TTS down → mode dégradé (ticket basique créé)
- Tous les messages/prompts en français
- Clés API dans variables d'environnement (TWILIO_ACCOUNT_SID, DEEPGRAM_API_KEY, OPENAI_API_KEY, ELEVENLABS_API_KEY)
- Validation Twilio webhook obligatoire

## Fichiers à créer (4)
1. `services/api-backend/src/services/voice-ai.service.js`
2. `services/api-backend/src/services/classification.service.js`
3. `services/api-backend/src/controllers/voice-ai.controller.js`
4. `services/api-backend/src/routes/voice.routes.js`

## Fichiers à modifier (5)
5. `services/api-backend/src/services/notification.service.js`
6. `services/api-backend/src/services/maintenance.service.js`
7. `services/api-backend/src/routes/index.js`
8. `lib/services/maintenance_service.dart`
9. `lib/screens/maintenance_command_center_screen.dart`

## Vérification
- `npm run lint` dans services/api-backend/ → 0 erreur
- `flutter analyze` dans lib/ → 0 erreur
