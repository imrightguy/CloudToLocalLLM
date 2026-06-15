# BUGFIX — ~20 bugs mineurs audités (M1-M23)

Fixe ces bugs dans C:\Users\SimonGravel\ImmoGestion. Lis chaque fichier avant de modifier.
Priorité: backend d'abord, puis frontend, puis infra. Skip si trop risqué ou nécessite refactor majeur.

## BACKEND

### M1 — migrations/016_* numéro dupliqué
**Fichiers:** `migrations/016_*` (deux fichiers)
Deux fichiers portent le numéro 016. Idempotents donc pas de bug, mais à renuméroter.
**Fix:** Renommer le deuxième `016_*` en `024_*`.

### M2 — Code mort post-migration 021
**Fichiers:** `validation-schemas.js:12,213-232,566-606,743-817` + `models/tenant-checklist.js`, `models/photo.js`
Schémas et modèles pour des tables supprimées par la migration 021. Aucune route ne les câble.
**Fix:** Supprimer les schémas/models orphelins OU les commenter avec `// DEPRECATED: table dropped in migration 021`.

### M3 — setCacheHeaders contradictoires
**Fichier:** `utils/apiResponse.js:282-288`
`max-age` + `no-store` dans la même réponse = contradictoire.
**Fix:** Choisir l'un ou l'autre selon le contexte (no-store pour données dynamiques, max-age pour assets).

### M4 — setCORSHeaders défaut origin:'*'
**Fichier:** `utils/apiResponse.js:296-313`
`origin:'*'` utilisé seulement sur `/health` (credentials false) mais reste un piège.
**Fix:** Restreindre à la liste blanche CORS comme le reste de l'app.

### M5 — FK leads sans ON DELETE
**Fichier:** `database/schema.js` (table leads)
`building_id`, `unit_id`, `assigned_employee_id` sans `ON DELETE` → `NO ACTION` bloque les suppressions.
**Fix:** Ajouter `onDelete: 'set null'` ou `onDelete: 'cascade'` selon la sémantique.

### M6 — maintenance_tickets.tenant_id sans FK
**Fichier:** `database/schema.js` (table maintenance_tickets)
UUID sans référence → pas d'intégrité référentielle.
**Fix:** Ajouter `.references(() => tenantsTable.id, { onDelete: 'set null' })`.

### M7 — Index composite payments désync
**Fichier:** `database/schema.js` (table payments)
Index `payments(lease_id, due_date)` présent en migration mais absent du schéma Drizzle.
**Fix:** Ajouter l'index dans le schéma Drizzle.

### M8 — Pas de politique de complexité de mot de passe
**Fichier:** `controllers/auth.controller.js` (register/changePassword)
Longueur ≥8 seulement.
**Fix:** Ajouter validation: min 8 chars, au moins 1 majuscule + 1 chiffre + 1 spécial.

### M9 — seed.js stub vide
**Fichier:** `scripts/seed.js` ou `database/seed.js`
No-op.
**Fix:** Supprimer le fichier OU ajouter un commentaire `// Intentionally empty — seed data is in migrations`.

### M10 — Validation redondante createLead
**Fichier:** `controllers/lead.controller.js:21-26`
Validation manuelle déjà couverte par Joi.
**Fix:** Retirer la validation manuelle redondante.

## FRONTEND

### M11 — Écrans d'erreur ad hoc → ErrorState
**Fichiers:** `lease_form_screen.dart:203-224`, `sms_conversation_screen.dart:216-237`, `calendar_screen.dart`
`e.toString()` exposé directement au lieu du widget partagé `ErrorState`.
**Fix:** Remplacer par le widget `ErrorState` partagé.

### M12 — EmptyState avec CTA non câblé
**Fichiers:** `leases_screen.dart:134`, `leads_screen.dart:118`
Bouton d'action dans EmptyState qui ne fait rien.
**Fix:** Câbler le `onCtaPressed` vers l'action appropriée (création).

### M13 — Double-submit sur dialogues
**Fichiers:** `maintenance_screen.dart:339`, `renovation_orders_screen.dart:281`
Pas de guard contre le double-tap sur les boutons de dialogue.
**Fix:** Ajouter `_isSubmitting` flag ou désactiver le bouton après premier tap.

### M14 — Code mort _missingCompanyAccess
**Fichier:** `home_screen.dart:424-502,515,858-864`
`_missingCompanyAccess` jamais mis à `true` → widget `_CompanyAccessMissingState` inatteignable.
**Fix:** Supprimer le code mort OU l'activer avec une condition réelle.

### M15 — Garde d'auth basée sur présence token
**Fichier:** `main.dart:97-104`
Vérifie juste la présence du token, pas son expiration → flash d'écran protégé avec token expiré.
**Fix:** Décoder le token et vérifier `exp` avant de considérer l'utilisateur comme authentifié.

### M16 — Logique de routage dupliquée
**Fichier:** `main.dart:163-206` vs `385-435`
Deux blocs de routage avec conditions divergentes.
**Fix:** Extraire en une fonction partagée `_buildRoutes()`.

### M17 — _themeMode redondant + initializeDateFormatting 2x
**Fichier:** `main.dart:38-39,85-86`
State local + ValueNotifier static = risque de désync. `initializeDateFormatting` appelé deux fois.
**Fix:** Utiliser UNIQUEMENT le ValueNotifier. Retirer le deuxième appel à initializeDateFormatting.

### M18 — _tryRefresh utilise http.post global
**Fichier:** `api_service.dart` (méthode _tryRefresh)
`http.post` global au lieu du `client` injectable → non mockable en test.
**Fix:** Utiliser `client.post` (le client injecté).

### M19 — Chaînes/breakpoints/styles en dur
**Fichiers:** `dashboard:81-84` (mois FR), divers (breakpoints 1024/1280/720, fontSize inline)
**Fix:** Centraliser les mois FR dans une constante. Pas nécessaire de tout migrer — juste les plus évidents.

## INFRA

### M20 — DEMO_MODE jamais lu
**Fichiers:** `docker-compose.yml:50,93` + `src/`
Passé aux conteneurs mais jamais référencé dans le code.
**Fix:** Ajouter un commentaire dans docker-compose.yml OU retirer la variable.

### M21 — Images non épinglées
**Fichier:** `docker-compose.yml`
`cloudflared:latest`, `postgres:16-alpine` (major seul).
**Fix:** Épingler avec des digests SHA256 ou tags précis (ex: `postgres:16.3-alpine`).

### M22 — flutter-web sans limits.memory
**Fichier:** `docker-compose.yml` (service flutter-web)
L'API a `deploy.resources.limits.memory`, pas flutter-web.
**Fix:** Ajouter `deploy.resources.limits.memory: 256M` au service flutter-web.

### M23 — Double mécanisme migrations
**Fichiers:** `docker-compose.yml` + `scripts/migrate.js`
`./migrations:/docker-entrypoint-initdb.d` ne s'exécute qu'au premier init. Les migrations suivantes passent par `scripts/migrate.js`.
**Fix:** Ajouter un commentaire explicatif dans docker-compose.yml.