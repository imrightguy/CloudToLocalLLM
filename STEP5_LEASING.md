# ÉTAPE 5 — Module Leasing (webhook Marketplace + Hermes)

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/.

## Contexte
Le nettoyage est fait. Le dashboard a déjà les 3 piliers. Tu dois MAINTENANT créer le module Leasing.

## Ce qui existe DÉJÀ
- Table `leads` dans schema.js (colonnes: id, firstName, lastName, phone, email, source, stage, notes, propertyId, createdAt, updatedAt)
- Controller `leads.controller.js` (CRUD basique)
- Routes `lead.routes.js`
- Service `analytics.service.js` (KPIs leasing déjà calculés)
- Dashboard Flutter avec `_buildPillarsSection()` (carte Leasing déjà affichée)

## Ce que tu dois CRÉER

### Backend — Nouveaux fichiers

**1. services/api-backend/src/services/leasing.service.js**
Service pour le flux leasing complet. Méthodes:
- `createFromMarketplace(data)` — reçoit {name, phone, email, source, message, propertyId}, crée un lead avec stage='nouveau'
- `updateStage(id, stage, notes)` — met à jour le stage d'un lead (ex: Hermes qualifie → 'qualifié')
- `listLeads(filters)` — liste avec filtres (stage, source, limit, offset)
- `getById(id)` — fiche lead

**2. services/api-backend/src/controllers/leasing.controller.js**
Contrôleur avec ces handlers:
- `webhookMarketplace` — POST /api/leasing/webhook/marketplace — reçoit le webhook, crée le lead, retourne 201
- `updateStage` — PUT /api/leasing/leads/:id/stage — body {stage, notes}
- `listLeads` — GET /api/leasing/leads — query params (stage, source)
- `getLead` — GET /api/leasing/leads/:id

**3. services/api-backend/src/routes/leasing.routes.js**
Routes Express:
- POST /api/leasing/webhook/marketplace → webhookMarketplace (SANS auth — c'est un webhook externe)
- PUT /api/leasing/leads/:id/stage → updateStage (avec auth)
- GET /api/leasing/leads → listLeads (avec auth)
- GET /api/leasing/leads/:id → getLead (avec auth)

**4. Enregistrer les routes dans server.js ou routes/index.js**
Ajouter `app.use('/api/leasing', leasingRoutes)` dans le fichier qui monte les routes.

### Frontend — Nouveaux fichiers

**5. lib/services/leasing_service.dart**
Service Flutter pour appeler l'API leasing:
- `listLeads({stage, source})` → GET /api/leasing/leads
- `getLead(id)` → GET /api/leasing/leads/:id
- `updateLeadStage(id, stage, notes)` → PUT /api/leasing/leads/:id/stage

**6. lib/screens/leads_screen.dart**
Écran liste des leads avec:
- AppBar "Pistes"
- Filtres par stage (Chip: Nouveau, Qualifié, Visité, Signé, Perdu)
- Filtre par source (Kijiji, Facebook, Marketplace)
- Liste avec cards: nom, téléphone, source, stage (badge coloré), date
- Pull-to-refresh
- Tap → navigate to lead_detail

**7. lib/screens/lead_detail_screen.dart**
Écran fiche lead avec:
- AppBar avec nom du lead
- Carte info: nom, téléphone, email, source, date création
- Badge stage (coloré)
- Bouton "Modifier le statut" → dropdown avec stages
- Section notes
- Bouton "Planifier une visite" → navigate to visit_form

### Intégration Hermes

**8. lib/services/hermes_service.dart**
Service pour notifier Hermes (sur MacBook Air):
- `notifyNewLead(lead)` — POST vers webhook Hermes (URL configurable)
- Méthode: POST avec body {event: 'new_lead', lead: {...}}

## Vérification
Après avoir tout créé:
1. `npm run lint` dans services/api-backend/ — 0 nouvelle erreur
2. `flutter analyze` dans lib/ — 0 nouvelle erreur
3. Liste chaque fichier créé avec son chemin absolu

## Règles
- Code existant: lis avant de modifier
- Français québécois pour les strings UI
- Anglais pour le code
- Pas de commentaires
- Si un fichier existe déjà, étends-le au lieu de le recréer
