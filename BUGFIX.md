# BUGFIX — 7 bugs ImmoGestion v3

Fixe ces bugs dans C:\Users\SimonGravel\ImmoGestion. Lis chaque fichier avant de modifier.

## 🔴 CRITIQUES (bloquants)

### B1. Calendrier cassé — 400 VALIDATION_ERROR
**Fichier:** `services\api-backend\src\config\validation-schemas.js` lignes 298-299
**Cause:** `Joi.date().iso()` exige format ISO complet (`2026-06-01T00:00:00.000Z`) mais le client Flutter envoie `dateFrom=2026-06-01` (date seule).
**Fix:** Remplacer `Joi.date().iso()` par `Joi.date()` dans `visitSchemas.list.query` (lignes 298-299). `Joi.date()` accepte `YYYY-MM-DD`.

### B2. Conversations SMS — 404 NOT_FOUND (segment vide)
**Fichier:** `lib\services\communication_service.dart` ligne 95
**Cause:** `/sms/conversation/$contactId?$query` — quand `contactId` est vide/null, l'URL devient `/sms/conversation/?page=1&limit=50`
**Fix:** Ajouter une guard: si `contactId` est vide, retourner `[]` immédiatement. Ou tracer l'appelant pour trouver pourquoi contactId est vide.

### B3. API visits filtrée par date — 400 (même cause que B1)
**Même fix que B1** — changer `Joi.date().iso()` → `Joi.date()` dans `visitSchemas.list.query`.

### B4. Piliers dashboard non cliquables
**Fichier:** `lib\screens\dashboard_screen.dart` — chercher les 3 cartes Leasing/Maintenance/Rénovation avec flèche `›`
**Fix:** Ajouter `onTap` avec navigation vers l'écran correspondant (`/leases`, `/maintenance`, `/renovations`).

### B5. Bouton "Nouvelle piste" → mauvais écran
**Fichier:** `lib\screens\dashboard_screen.dart` — chercher `Nouvelle piste` + `onTap`/`onPressed`
**Fix:** Remplacer la navigation vers `/communications` par l'ouverture du formulaire de création de lead (`LeadFormScreen` ou navigation vers `/leads` avec action create).

## 🟡 MINEURS

### B6. Avatars "?" dans Messages
**Fichier:** `lib\screens\communications_screen.dart` — liste des conversations
**Cause:** Les contacts n'ont pas de nom/initiale extrait correctement.
**Fix:** Extraire `contactName` ou `phoneNumber` et afficher l'initiale (première lettre) au lieu de `?`.

### B7. Incohérence "Visites cette semaine"
**Fichier:** `lib\screens\dashboard_screen.dart` + `lib\screens\home_screen.dart`
**Cause:** Dashboard compte les visites planifiées, Accueil compte les complétées.
**Fix:** Ajouter un label explicite: "Visites planifiées cette semaine" vs "Visites complétées cette semaine".

## RÈGLES
- Lis chaque fichier avant de modifier
- Utilise `patch` (mode replace) pour chaque fix
- Vérifie avec `flutter analyze` après les changements Dart
- Commence par B1 (débloque B3 aussi)
