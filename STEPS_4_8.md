# ImmoGestion v3 — Étapes 4 à 8 (Bloc Architecture)

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/. Le nettoyage (étape 3) est terminé — les modules Marketplace, Pipeline, Onboarding, Démo, Documents, Dossiers TAL, Tenant checklist, WhatsApp, Messenger, Facebook ont été supprimés. Flutter analyze passe (0 erreur), flutter build web réussit.

## Objectif
Implémenter les 5 étapes restantes pour transformer ImmoGestion en complément professionnel à PlexFlow, avec 3 piliers : Leasing, Maintenance, Rénovation.

## Architecture cible

```
ImmoGestion v3
├── Auth (JWT, login/register)
├── Parc immobilier (lecture PlexFlow)
├── 📋 LEASING — webhook Marketplace → Hermes qualifie → visites → bail
├── 🔧 MAINTENANCE — Voice AI Agent (Vapi) répond aux appels/textos
├── 🛠️ RÉNOVATION — commandes matériaux, tâches, photos
└── 📊 DASHBOARD — vue unifiée 3 piliers + KPIs
```

## Règles absolues
- Lis chaque fichier avant de le modifier
- Backend : npm run lint doit passer après chaque étape
- Frontend : flutter analyze doit passer après chaque étape
- Ne casse rien d'existant — les modules Gardés (auth, buildings, units, leases, payments, leads, visits, calendar, sms, concierges, dashboard, settings) doivent continuer à fonctionner
- Langue : français québécois pour les strings, anglais pour le code
- Pas de commentaires dans le code

---

## ÉTAPE 4 — Refonte Dashboard (3h)

### Objectif
Refondre le dashboard pour afficher une vue unifiée des 3 piliers : Leasing, Maintenance, Rénovation.

### Backend : services/api-backend/src/services/analytics.service.js
- Créer ou modifier le service pour fournir des KPIs par pilier :
  - Leasing : leads actifs, visites cette semaine, taux de conversion
  - Maintenance : tickets ouverts, temps moyen de résolution
  - Rénovation : projets en cours, budget restant
- Ajouter les routes API correspondantes dans routes/analytics.js

### Frontend : lib/screens/dashboard_screen.dart
- Refondre avec 3 cartes principales (une par pilier)
- Chaque carte montre les KPIs du pilier
- Style : Material 3, thème teal existant, cartes avec elevation
- Remplacer les graphiques fl_chart par des cartes KPI simples (les graphiques peuvent revenir plus tard)

---

## ÉTAPE 5 — Module Leasing unifié (6h)

### Objectif
Créer le module Leasing : webhook Marketplace → Hermes (sur MacBook Air) qualifie → visites → bail.

### Backend
**Nouveau service :** services/api-backend/src/services/leasing.service.js
- Endpoint webhook pour recevoir les messages Marketplace (Kijiji/Facebook Marketplace)
- Stocke le lead dans la table leads existante
- Envoie une notification à Hermes (webhook sortant vers l'endpoint Hermes sur MacBook)

**Nouveau contrôleur :** services/api-backend/src/controllers/leads.controller.js (si pas déjà existant)
- CRUD leads avec champs : nom, téléphone, email, source (kijiji/facebook), statut (nouveau/qualifié/visité/signé/perdu), notes
- Endpoint pour mettre à jour le statut après qualification Hermes

**Routes :** services/api-backend/src/routes/leads.js
- POST /api/leads (création lead)
- GET /api/leads (liste avec filtres)
- PUT /api/leads/:id (mise à jour statut)
- POST /api/leads/webhook/marketplace (réception webhook)

### Frontend
**Nouveaux écrans :**
- lib/screens/leads_screen.dart — liste des leads avec filtres (statut, source, date)
- lib/screens/lead_detail_screen.dart — fiche lead avec historique des communications, visites, documents
- lib/screens/visit_screen.dart — planification des visites (existant? à vérifier)
- lib/screens/visit_form_screen.dart — formulaire de visite (existant? à vérifier)

**Services :**
- lib/services/lead_service.dart — API client pour les leads
- lib/services/visit_service.dart — API client pour les visites (existant? à vérifier)

**Intégration Hermes :**
- Ajouter un service lib/services/hermes_service.dart pour envoyer des notifications à Hermes
- Quand un nouveau lead arrive via webhook → notifier Hermes → Hermes qualifie → mise à jour statut

---

## ÉTAPE 6 — Module Maintenance Voice AI (4h)

### Objectif
Intégrer un Voice AI Agent (Vapi) pour répondre aux appels/textos des locataires 24/7.

### Backend
**Nouveau service :** services/api-backend/src/services/maintenance.service.js
- Endpoint webhook pour recevoir les appels/textos Vapi
- Stocke les tickets dans une nouvelle table maintenance_tickets
- Associe le numéro appelant au locataire (lookup dans la table units/locataires via PlexFlow)

**Nouveau contrôleur :** services/api-backend/src/controllers/maintenance.controller.js
- CRUD tickets : titre, description, urgence (basse/moyenne/haute/urgence), statut (ouvert/en_cours/résolu), locataire_id, unité_id, photos
- Endpoint webhook pour Vapi

**Routes :** services/api-backend/src/routes/maintenance.js
- POST /api/maintenance/tickets (création)
- GET /api/maintenance/tickets (liste avec filtres)
- PUT /api/maintenance/tickets/:id (mise à jour)
- POST /api/maintenance/webhook/vapi (réception webhook Vapi)

**Nouvelle table :** maintenance_tickets
- Colonnes : id, title, description, urgency, status, tenant_id, unit_id, building_id, photos[], created_at, updated_at
- Migration SQL à créer

### Frontend
**Nouveaux écrans :**
- lib/screens/maintenance_screen.dart — dashboard maintenance avec liste des tickets
- lib/screens/maintenance_ticket_detail.dart — fiche ticket avec chat, photos, statut

**Services :**
- lib/services/maintenance_service.dart — API client

---

## ÉTAPE 7 — Module Rénovation (3h)

### Objectif
Fusionner rénovation et maintenance. Module de gestion des rénovations avec commandes de matériaux.

### Backend
**Service existant à vérifier :** services/api-backend/src/services/renovation.service.js
- Si existe déjà, étendre avec les commandes de matériaux
- Sinon, créer

**Nouvelles routes :** services/api-backend/src/routes/renovation.js
- CRUD projets de rénovation
- CRUD commandes de matériaux (liées à un projet)
- Upload photos avant/après

**Tables existantes à vérifier :** renovations, renovation_tasks, renovation_orders
- Si elles existent déjà (gardées dans l'étape 3), les utiliser
- Sinon, créer les migrations nécessaires

### Frontend
**Écran existant à vérifier :** lib/screens/renovation_ops_screen.dart
- Si existe déjà, étendre avec les commandes de matériaux
- Sinon, créer

**Service :** lib/services/renovation_service.dart — API client

---

## ÉTAPE 8 — Synchronisation PlexFlow (3h)

### Objectif
Connecter ImmoGestion à PlexFlow en lecture seule pour les données immobilières.

### Backend
**Nouveau service :** services/api-backend/src/services/plexflow.service.js
- Client API pour PlexFlow (endpoint à configurer)
- Méthodes : getBuildings(), getUnits(buildingId), getLeases(unitId), getTenants(unitId)
- Cache des données PlexFlow (TTL 1h) pour éviter les appels répétés
- Endpoint de synchronisation périodique (toutes les heures)

**Nouveau contrôleur :** services/api-backend/src/controllers/plexflow.controller.js
- GET /api/plexflow/buildings → liste des immeubles
- GET /api/plexflow/buildings/:id/units → logements d'un immeuble
- GET /api/plexflow/units/:id/leases → baux d'un logement
- GET /api/plexflow/units/:id/tenants → locataires d'un logement
- POST /api/plexflow/sync → déclencher synchronisation manuelle

**Nouvelles routes :** services/api-backend/src/routes/plexflow.js

### Frontend
**Service :** lib/services/plexflow_service.dart — API client
**Utilisation :** injecter les données PlexFlow dans les écrans buildings/units/leases existants

---

## Vérification finale
1. npm run lint — 0 erreur
2. flutter analyze — 0 erreur
3. flutter build web — réussi
4. npm test — tous les tests passent
5. Lister chaque étape complétée avec ce qui a été fait

## Priorité
Exécute dans l'ordre : 4 → 5 → 6 → 7 → 8. Si une étape dépend d'une autre (ex: les services créés à l'étape 5 sont utilisés à l'étape 6), assure-toi que la dépendance est satisfaite.
