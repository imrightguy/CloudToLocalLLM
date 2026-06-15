# BUGFIX — 13 bugs importants audités (I1-I13)

Fixe ces 13 bugs dans C:\Users\SimonGravel\ImmoGestion. Lis chaque fichier avant de modifier.

## I1 — IDOR sur les photos & templates
**Fichiers:** `routes/photo.routes.js:11-14` + `controllers/photo.controller.js:39-58`
`companyId` pris depuis l'URL sans vérifier l'appartenance. Un utilisateur valide peut lister/uploader les photos de n'importe quelle company.
**Fix:** Vérifier `req.params.companyId` contre la company autorisée, 403 sinon.

## I2 — Bypass webhooks Vapi & Marketplace si secret absent
**Fichiers:** `controllers/maintenance.controller.js:109-118` + `controllers/lead.controller.js:336-345` + webhook PlexFlow
`if (expectedSecret) { ... }` — si la variable d'env n'est pas définie, la vérification est sautée (fail-open). Comparaison aussi sensible aux attaques temporelles (`!==`).
**Fix:** Rejeter 401 si secret absent (fail-closed), `crypto.timingSafeEqual`.

## I3 — optionalAuth sélectionne passwordHash
**Fichier:** `auth/jwt.middleware.js:53`
`optionalAuth` fait `db.select()` complet et place tout l'objet user (dont `passwordHash`) dans `req.user`.
**Fix:** Projeter les mêmes colonnes sûres que `authenticateToken` (sans `passwordHash`).

## I4 — Énumération de comptes au register
**Fichier:** `controllers/auth.controller.js:61-66`
409 `USER_ALREADY_EXISTS` permet d'énumérer les emails valides.
**Fix:** Réponse neutre identique (ex: "If the email is available, a verification email has been sent").

## I5 — GET /leases?buildingId=... → 500
**Fichier:** `controllers/lease.controller.js:144-174`
`eq(buildingsTable.id, buildingId)` ajouté mais la requête données n'a pas les `leftJoin` units+buildings → SQL erreur.
**Fix:** Répliquer les `leftJoin` sur la requête de données.

## I6 — POST /leads/bulk cassé
**Fichiers:** `routes/lead.routes.js:460` + `controllers/lead.controller.js:399-444`
Route valide `{leadIds, updates:{status}}`, contrôleur lit `req.body.ids` et `updates.stage` → toujours undefined → 400.
**Fix:** Aligner les noms (`leadIds`↔`ids`, `status`↔`stage`).

## I7 — GET de liste sans validation UUID
**Fichiers:** `lease.routes.js:58`, `lead.routes.js:110`
`buildingId`/`unitId` non-UUID atteignent Drizzle → erreur Postgres `22P02` → 500 au lieu de 400.
**Fix:** Schémas Joi `query` (UUID + enums) sur les GET de liste.

## I8 — Aucun timeout HTTP
**Fichier:** `lib/services/api_service.dart:145-160` et `:217`
`http.Client` sans timeout → requête pend indéfiniment.
**Fix:** `.timeout(Duration(seconds: 30), onTimeout: ...)` factorisé dans `_request`.

## I9 — _tryRefresh avale toutes les erreurs → logout abusif
**Fichier:** `lib/services/api_service.dart:234` (`catch (_) {}`)
Coupure réseau momentanée pendant refresh → logout.
**Fix:** Ne forcer logout que sur 401/403 du endpoint refresh, propager l'erreur réseau sans purger les tokens.

## I10 — DateTime.parse non protégé
**Fichiers:** `lib/models.dart:146,533,743,863,1465,1468,1968` + `analytics_service.dart:37,138` + `activity_service.dart:44`
Date malformée = crash écran.
**Fix:** Utiliser un helper `_tryParseDate` partout.

## I11 — Casts non protégés dans les chemins auth
**Fichiers:** `api_service.dart:249-250,255,276-277,282,298` + `auth_service.dart:95` + `models.dart:272`
`result['data'] as Map<String,dynamic>` sans vérif → TypeError.
**Fix:** Valider présence/type avant cast, lever ApiException.

## I12 — setState après async sans mounted
**Fichiers:** dashboard:62/72, home:691/698, leases:93/98/116, payments:41/47, leads:56/61, calendar:59/64, lease_form:93/98/116, lease_detail:60/127/195, settings:83/129
Widget peut être disposé pendant le fetch → "setState() called after dispose()".
**Fix:** `if (!mounted) return;` après chaque `await` précédant un `setState`.

## I13 — int.parse sur champs sans validateur
**Fichiers:** `lease_form_screen.dart:144,146` + `buildings_screen.dart:668,669`
`int.parse` sur saisie vide → FormatException → perte de données.
**Fix:** `int.tryParse(...) ?? 0` + `FilteringTextInputFormatter.digitsOnly`.