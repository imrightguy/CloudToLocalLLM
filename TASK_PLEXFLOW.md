# TASK — PlexFlow Ingestion Automatique + Gap Analysis

Tu es un développeur senior full-stack (Node.js/Express/Drizzle/PostgreSQL + Flutter). Implémente l'ingestion automatique PlexFlow → ImmoGestion et le gap analysis.

## Contexte
ImmoGestion = SaaS gestion locative. PlexFlow = API externe (clé: pf_4UVetZZeOfcomnIuElkgGx9FCWfQGrXf) qui contient les données réelles des bâtiments, unités, baux, locataires. Actuellement PlexFlow est read-only (proxy + cache TTL 1h). On veut pouvoir:
1. Comparer PlexFlow vs DB locale → identifier les gaps
2. Ingérer automatiquement les données manquantes
3. Afficher le gap analysis dans l'UI Flutter

## Stack
Backend: Node.js/Express/Drizzle/PostgreSQL (services/api-backend/src/)
Frontend: Flutter Web Material 3 (lib/)

## État actuel ✅
- `plexflow.service.js` — proxy read-only: getBuildings, getUnits, getLeases, getTenants, syncAll (cache TTL 1h)
- `plexflow.controller.js` — endpoints REST: GET /plexflow/buildings, /plexflow/buildings/:id/units, etc.
- `plexflow_service.dart` — client Flutter: getBuildings, getUnits, getLeases, getTenants, sync
- `building_service.dart` — CRUD buildings/units local
- `lease_service.dart` — CRUD leases local
- `database/schema.js` — tables: buildings, units, leases

## Ce que tu dois implémenter

### 1. PlexFlow — Full Snapshot + Gap Analysis (backend — modifier 1 fichier)

**Modifier `services/api-backend/src/services/plexflow.service.js`**

Ajouter:
- `getFullSnapshot(buildingId)` — retourne TOUTES les données PlexFlow pour un bâtiment (building + units + leases + tenants) en un seul appel
- `compareWithLocal(buildingId)` — compare le snapshot PlexFlow avec la DB locale:
  - Récupère le snapshot PlexFlow
  - Récupère les données locales (units, leases) pour ce buildingId
  - Compare et retourne:
    ```json
    {
      "buildingId": "...",
      "buildingName": "...",
      "missingUnits": [{plexflowId, label, floor, rooms}],
      "missingLeases": [{plexflowId, unitLabel, tenantName, rent, startDate, endDate}],
      "missingTenants": [{plexflowId, name, phone, email, unitLabel}],
      "extraInLocal": [{type: "unit"|"lease", id, label}],
      "summary": {totalInPlexflow, totalInLocal, missingCount, extraCount}
    }
    ```
- La comparaison se fait par `plexflowId` (un champ dans properties JSON de chaque record local, ou un champ dédié)

### 2. PlexFlow — Ingestion Service (backend — 1 nouveau fichier)

**`services/api-backend/src/services/plexflow-ingestion.service.js`**

- `ingestMissingData(buildingId)` — prend le rapport de `compareWithLocal` et crée les enregistrements manquants:
  - Pour chaque missingUnit → `buildingService.createUnit(buildingId, data)`
  - Pour chaque missingLease → `leaseService.createLease(data)` (avec unitId résolu)
  - Pour chaque missingTenant → mettre à jour l'unit avec tenantName, tenantPhone, tenantEmail
  - Respecte l'ordre FK: building existe → unit → lease → tenant
  - Retourne un rapport: `{createdUnits: N, createdLeases: N, updatedTenants: N, errors: []}`
  - Transaction: si une étape échoue, rollback partiel (log l'erreur, continue les autres)

### 3. Controller + Routes (backend — modifier 2 fichiers)

**Modifier `services/api-backend/src/controllers/plexflow.controller.js`**

Ajouter:
- `exports.getGapAnalysis` → GET /plexflow/buildings/:id/gap-analysis
  - Appelle `plexflowService.compareWithLocal(req.params.id)`
  - Retourne le rapport JSON
  
- `exports.ingestMissing` → POST /plexflow/buildings/:id/ingest
  - Appelle `plexflowIngestionService.ingestMissingData(req.params.id)`
  - Retourne le rapport d'ingestion

**Modifier `services/api-backend/src/routes/index.js`**

Ajouter (dans le bloc plexflow existant):
- `router.get('/buildings/:id/gap-analysis', plexflowController.getGapAnalysis)`
- `router.post('/buildings/:id/ingest', plexflowController.ingestMissing)`

### 4. Client Flutter (modifier 1 fichier)

**Modifier `lib/services/plexflow_service.dart`**

Ajouter:
- `getGapAnalysis(String buildingId)` → GET /plexflow/buildings/$buildingId/gap-analysis
- `ingestMissing(String buildingId)` → POST /plexflow/buildings/$buildingId/ingest

### 5. UI Flutter — Gap Analysis Screen (1 nouveau fichier)

**`lib/screens/plexflow_gap_screen.dart`**

Écran Flutter Material 3:
- Liste des bâtiments (depuis PlexFlow)
- Pour chaque bâtiment, cliquable → affiche le gap analysis:
  - Card "Unités manquantes" avec liste (label, floor, rooms) + compteur
  - Card "Baux manquants" avec liste (unitLabel, tenantName, rent) + compteur
  - Card "Locataires manquants" avec liste (name, phone, unitLabel) + compteur
  - Card "En trop dans ImmoGestion" (extraInLocal)
  - Bouton "Importer les données manquantes" → appelle ingestMissing → snackbar succès/erreur
- États: loading (ListSkeleton), erreur (ErrorState), vide (EmptyState "Aucun gap détecté")
- Accessible depuis Settings → Intégrations → PlexFlow (ajouter un ListTile dans settings_screen.dart)

### 6. Settings Screen (modifier 1 fichier)

**Modifier `lib/screens/settings_screen.dart`**

Ajouter un ListTile "PlexFlow — Analyse des écarts" qui navigue vers PlexFlowGapScreen.

## Règles strictes
- Réutilise plexflow.service.js (getBuildings, getUnits, getLeases, getTenants, cache TTL 1h)
- Réutilise building_service.dart (createUnit) et lease_service.dart (createLease)
- Pas de breaking changes sur les endpoints existants
- Utilise le logger existant (`require('../utils/logger')`)
- Cache PlexFlow: ne pas invalider le cache pendant l'ingestion (le snapshot est frais)
- Fallback: si PlexFlow down → retourne `{configured: false, error: "PlexFlow indisponible"}`
- Tous les messages UI en français
- Utilise les widgets existants: ListSkeleton, ErrorState, EmptyState, StatusBadge

## Fichiers à créer (2)
1. `services/api-backend/src/services/plexflow-ingestion.service.js`
2. `lib/screens/plexflow_gap_screen.dart`

## Fichiers à modifier (4)
3. `services/api-backend/src/services/plexflow.service.js`
4. `services/api-backend/src/controllers/plexflow.controller.js`
5. `lib/services/plexflow_service.dart`
6. `lib/screens/settings_screen.dart`

## Vérification
- `npm run lint` dans services/api-backend/ → 0 erreur
- `flutter analyze` dans lib/ → 0 erreur
