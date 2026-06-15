# Audit complet — ImmoGestion v3

> Audité le 2026-06-15 sur la branche `agent/spark/immogestion-v3`.
> Périmètre : backend Node/Express/Drizzle (80 fichiers), frontend Flutter Web (80 fichiers), infra Docker/Nginx/Cloudflare.
> Les éléments marqués **✓ vérifié** ont été confirmés en lisant le code source directement.

## Synthèse exécutive

L'implémentation est globalement **de bonne qualité** : secrets validés au démarrage, bcrypt, helmet/CORS restreints, rate limiting, parsing JSON défensif, disposal des controllers Flutter rigoureux. Les défauts les plus graves ne sont pas des failles de sécurité classiques mais **deux régressions fonctionnelles qui cassent des parcours entiers en production** (refresh token + création de bail), masquées par des tests qui mockent des structures absentes de la vraie base.

| Sévérité | Nombre | Effort total |
|---|---|---|
| 🔴 CRITIQUE | 6 | ~9 h |
| 🟡 IMPORTANT | 13 | ~24 h |
| 🟢 MINEUR | ~20 | ~12 h |

---

## 🔴 CRITIQUE — à corriger immédiatement

### C1 — Refresh token TOUJOURS rejeté en production (refresh cassé) — **✓ vérifié**
**`src/controllers/auth.controller.js:289`** + `src/database/schema.js:29-39` + `migrations/001_initial_schema.sql:24-32`
`refreshAccessToken` compare `user.tokenVersion !== tokenRecord.tokenVersion`. Or la table `refresh_tokens` **n'a aucune colonne `token_version`** (ni migration, ni schéma Drizzle, ni l'INSERT lignes 99-105/310-316). `tokenRecord.tokenVersion` vaut donc toujours `undefined`, `user.tokenVersion` vaut ≥1 → la condition est toujours vraie → **chaque rafraîchissement renvoie 401 `TOKEN_VERSION_MISMATCH` et supprime le token**. Le refresh est inutilisable : tous les utilisateurs sont déconnectés à l'expiration de l'access token (24h).
**Piège** : le test `auth.controller.test.js:55` invente un champ `tokenVersion` dans le mock de `refreshTokensTable`, donc la suite passe au vert alors que la prod échoue.
**Fix** : retirer la comparaison `tokenVersion` (lignes 289-299) — la rotation des tokens suffit déjà à détecter la réutilisation — OU ajouter réellement la colonne `token_version` à `refresh_tokens` (migration + schéma + INSERT). Corriger aussi le mock de test pour refléter le vrai schéma.
**Effort : 1,5 h**

### C2 — Création de bail TOUJOURS en échec (double validation incompatible) — **✓ vérifié**
**`src/routes/lease.routes.js:121`** + `src/controllers/lease.controller.js:43` + `validation-schemas.js:182-189` + `models/lease.js:13`
La route applique `validate(leaseSchemas.create)` avec `stripUnknown:true` (validate.js:8-10) : elle ne garde que `{unitId, buildingId, tenantId, startDate, endDate, rentAmount}` et **réécrit `req.body`**. Le contrôleur re-valide ensuite ce body réduit avec `leaseSchema` (models/lease.js) qui **exige `tenantFirstName`, `tenantLastName`, `rent`** (champs déjà supprimés) et **rejette les clés inconnues** (`tenantId`, `rentAmount`…). Résultat : `POST /leases` renvoie systématiquement 400. Même incompatibilité sur `PATCH /leases/:id` (`leaseSchemas.update` {rentAmount} vs `updateLeaseSchema` {rent, tenantFirstName…}).
**Fix** : supprimer un des deux systèmes. Recommandé : retirer `leaseSchemas.create/update` de la route (`router.post('/', authenticateToken, asyncHandler(...))`) et conserver uniquement la validation du contrôleur via `models/lease.js`. Aligner le client Flutter (`lease_form_screen`) sur le contrat retenu.
**Effort : 2 h**

### C3 — Confusion d'algorithme JWT / `alg:none` non bloqué
**`src/auth/jwt.middleware.js:15`** et `:52` (et génération `:61/:67`)
`jwt.verify(token, secret)` est appelé sans `{ algorithms: ['HS256'] }`. La librairie accepte alors tout algorithme listé dans l'en-tête du token, ouvrant la porte aux attaques de confusion d'algorithme.
**Fix** : `jwt.verify(token, secret, { algorithms: ['HS256'] })` partout, et `algorithm: 'HS256'` explicite à la génération.
**Effort : 0,5 h**

### C4 — Refresh token : signature jamais vérifiée + stocké en clair
**`src/controllers/auth.controller.js:239-243`** ; `schema.js:32`
Le refresh token est uniquement recherché par égalité de chaîne en base ; sa **signature JWT n'est jamais validée** avec `JWT_REFRESH_SECRET` (qui ne sert donc qu'à la génération). De plus il est **persisté en clair** : un dump/lecture SQL de `refresh_tokens` permet de rejouer directement les sessions de tous les utilisateurs (équivalent à stocker des mots de passe en clair).
**Fix** : valider `jwt.verify(refreshToken, JWT_REFRESH_SECRET, {algorithms:['HS256']})` avant le lookup ; stocker un `sha256(token)` en base et comparer le hash. (Mutualisable avec C1.)
**Effort : 2 h**

### C5 — JWT stockés dans `localStorage` (vulnérable au XSS) — frontend
**`lib/services/auth_token_storage_web.dart:39-55`**
`accessToken` et `refreshToken` sont écrits en clair dans `localStorage` (sous 4 clés). Sur le web, `localStorage` est lisible par tout script injecté : une seule faille XSS ou une dépendance compromise exfiltre le **refresh token** longue durée.
**Fix** : déplacer le refresh token vers un cookie `HttpOnly`/`Secure`/`SameSite=Strict` géré côté backend (le JS ne le voit jamais) ; garder l'access token en mémoire seulement. Nécessite coordination backend.
**Effort : 6-10 h**

### C6 — Controllers de dialogue jamais disposés (fuite mémoire) — frontend
**`lib/screens/maintenance_screen.dart:288-290`** et **`lib/screens/renovation_orders_screen.dart:245-247`**
Les `TextEditingController` créés dans `_showCreateDialog()` ne sont jamais disposés : chaque ouverture fuit 3 controllers.
**Fix** : `showDialog(...).then((_) { c1.dispose(); c2.dispose(); c3.dispose(); });` ou convertir le contenu en `StatefulWidget` dédié.
**Effort : 0,5 h**

---

## 🟡 IMPORTANT — cette semaine

### Sécurité / autorisation

**I1 — IDOR sur les photos & templates** — `routes/photo.routes.js:11-14` + `controllers/photo.controller.js:39-58`
`companyId` est pris depuis l'URL et passé au service **sans vérifier l'appartenance** de l'utilisateur. Un utilisateur valide peut lister/uploader/télécharger les photos de n'importe quelle company en changeant l'UUID. Idem `renovation-job-templates` (`routes/index.js:72`). *(Note : `usersTable` n'a pas de `companyId` — incohérence single-company vs schéma photos multi-tenant — qui rend le contrôle impossible aujourd'hui.)*
**Fix** : vérifier `req.params.companyId` contre la company autorisée, 403 sinon. **Effort : 3 h**

**I2 — Bypass des webhooks Vapi & Marketplace si secret absent** — `controllers/maintenance.controller.js:109-118` ; `controllers/lead.controller.js:336-345`
`if (expectedSecret) { ... }` : si la variable d'env n'est pas définie, la vérification est **entièrement sautée** (fail-open). Comparaison aussi sensible aux attaques temporelles (`!==`).
**Fix** : rejeter en 401 quand le secret est absent (fail-closed) ; `crypto.timingSafeEqual`. **Effort : 1 h**

**I3 — `optionalAuth` sélectionne `passwordHash`** — `auth/jwt.middleware.js:53`
Contrairement à `authenticateToken`, `optionalAuth` fait `db.select()` complet et place tout l'objet user (dont `passwordHash`) dans `req.user`. Piège pour tout futur handler exposant `req.user`.
**Fix** : projeter les mêmes colonnes sûres que `authenticateToken`. **Effort : 0,25 h**

**I4 — Énumération de comptes au register** — `controllers/auth.controller.js:61-66`
409 `USER_ALREADY_EXISTS` permet d'énumérer les emails valides (atténué mais non supprimé par le rate-limit 3/h). Le login, lui, est correctement générique.
**Fix** : réponse neutre / email de vérification. **Effort : 1 h**

### Bugs fonctionnels backend

**I5 — `GET /leases?buildingId=...` → 500** — `controllers/lease.controller.js:144-174` (**✓ pattern confirmé**)
La condition `eq(buildingsTable.id, buildingId)` est ajoutée, mais la requête de **données** (≠ requête de comptage) n'a pas les `leftJoin` units+buildings → SQL référence une table absente du FROM → erreur Postgres.
**Fix** : répliquer les `leftJoin` sur la requête de données (comme `payment.controller.js:204-214`). **Effort : 1 h**

**I6 — `POST /leads/bulk` cassé** — `routes/lead.routes.js:460` + `controllers/lead.controller.js:399-444`
La route valide `{leadIds, updates:{status}}` (stripUnknown), le contrôleur lit `req.body.ids` et `updates.stage` → toujours `undefined` → 400.
**Fix** : aligner les noms (`leadIds`↔`ids`, `status`↔`stage`). **Effort : 0,5 h**

**I7 — GET de liste sans validation des params UUID/enums** — `lease.routes.js:58`, `lead.routes.js:110`
`buildingId`/`unitId` non-UUID atteignent Drizzle → erreur Postgres `22P02` → 500 au lieu de 400. (Pas d'injection : requêtes paramétrées.)
**Fix** : schémas Joi `query` (UUID + enums) sur les GET de liste. **Effort : 1,5 h**

### Frontend — robustesse

**I8 — Aucun timeout HTTP** — `lib/services/api_service.dart:145-160` et `:217`
`http.Client` n'a pas de timeout par défaut : une requête peut pendre indéfiniment → spinners bloqués à vie.
**Fix** : `.timeout(Duration(seconds: 30), onTimeout: ...)` factorisé dans `_request`. **Effort : 1-2 h**

**I9 — `_tryRefresh` avale toutes les erreurs → logout abusif** — `lib/services/api_service.dart:234` (`catch (_) {}`)
Une coupure réseau momentanée pendant le refresh provoque un logout, alors qu'un retry aurait réussi.
**Fix** : ne forcer le logout que sur 401/403 du endpoint refresh ; propager l'erreur réseau sans purger les tokens. **Effort : 1-2 h**

**I10 — `DateTime.parse` non protégé (crash d'écran)** — `lib/models.dart:146, 533, 743, 863, 1465, 1468, 1968` ; `analytics_service.dart:37,138` ; `activity_service.dart:44`
Une date malformée renvoyée par l'API fait crasher tout le parsing (et l'écran). Des helpers `parseNullableDate`/`parseDate` existent déjà dans le fichier mais ne sont pas utilisés partout.
**Fix** : utiliser un helper `_tryParseDate` partout. **Effort : 1-2 h**

**I11 — Casts non protégés dans les chemins auth** — `api_service.dart:249-250, 255, 276-277, 282, 298` ; `auth_service.dart:95`
`result['data'] as Map<String,dynamic>` / `data['tokens'] as ...` sans vérif : si l'enveloppe serveur change → `TypeError` brut non traduit. `OfferItem.fromJson` (`models.dart:272`) : `(json['amount'] as num)` non-nullable → crash si null.
**Fix** : valider présence/type, lever `ApiException` ; `(json['amount'] as num?)?.toInt() ?? 0`. **Effort : 1 h**

**I12 — `setState` après async gap sans `if (!mounted)` (pattern répété)** — dashboard:62/72, home:691/698, leases:93/100, payments:41/47, leads:56/61, calendar:59/64, lease_form:93/98/116, lease_detail:60/127/195, settings:83/129
Sur les écrans poussés/dépilés, le widget peut être disposé pendant le fetch → « setState() called after dispose() ».
**Fix** : `if (!mounted) return;` après chaque `await` précédant un `setState`. **Effort : 1,5 h**

**I13 — `int.parse` sur champs sans validateur** — `lease_form_screen.dart:144,146` ; `buildings_screen.dart:668,669`
`FormatException` sur saisie vide/non numérique (clavier web non contraignant) → UX dégradée, données perdues.
**Fix** : `int.tryParse(...) ?? 0` + `validator` numérique / `FilteringTextInputFormatter.digitsOnly`. **Effort : 0,75 h**

---

## 🟢 MINEUR — nice to have

**Backend**
- **M1** `migrations/016_*` numéro dupliqué (deux fichiers `016`) → renuméroter en `023`. Idempotents donc pas de bug d'exécution. *(0,25 h)*
- **M2** Code mort post-migration 021 : `validation-schemas.js:12,213-232,566-606,743-817` (`tenantChecklistSchemas`, `documentSchemas`, `dossierCaseSchemas`, `observationResultSchemas`) + `models/tenant-checklist.js`, `models/photo.js` ciblent des tables supprimées. Aucune route ne les câble. *(1 h)*
- **M3** `setCacheHeaders` (`apiResponse.js:282-288`) émet des directives contradictoires (`max-age` + `no-store`). *(0,25 h)*
- **M4** `setCORSHeaders` (`apiResponse.js:296-313`) défaut `origin:'*'` — utilisé seulement sur `/health` (credentials false) mais piège à supprimer. *(0,5 h)*
- **M5** FK `leads.building_id/unit_id/assigned_employee_id` sans `ON DELETE` explicite → `NO ACTION` peut bloquer des suppressions. *(0,5 h)*
- **M6** `maintenance_tickets.tenant_id` est un UUID **sans FK** (pas d'intégrité référentielle). *(0,25 h)*
- **M7** Index composite `payments(lease_id, due_date)` présent en migration mais absent du schéma Drizzle (désync mineure). *(0,25 h)*
- **M8** Pas de politique de complexité de mot de passe (longueur ≥8 seule). *(0,5 h)*
- **M9** `seed.js` est un stub vide (no-op) — à supprimer ou implémenter. *(0,1 h)*
- **M10** Validation manuelle redondante `createLead` (`lead.controller.js:21-26`) déjà couverte par Joi. *(0,25 h)*

**Frontend**
- **M11** Écrans d'erreur ad hoc exposant `e.toString()` — `lease_form_screen.dart:203-224`, `sms_conversation_screen.dart:216-237`, `calendar_screen.dart` → utiliser le widget partagé `ErrorState`. *(1 h)*
- **M12** `EmptyState` avec CTA non câblé — `leases_screen.dart:134`, `leads_screen.dart:118` (bouton mort). *(0,25 h)*
- **M13** Double-submit possible sur dialogues `maintenance_screen.dart:339`, `renovation_orders_screen.dart:281`. *(0,5 h)*
- **M14** Code mort `_missingCompanyAccess` jamais mis à `true` → `_CompanyAccessMissingState` (home_screen.dart:424-502, 515, 858-864) inatteignable. *(0,25 h)*
- **M15** Garde d'auth (`main.dart:97-104`) basée sur la seule présence du token (pas de décodage `exp`) → flash d'écran protégé avec token expiré. *(2 h)*
- **M16** Logique de routage dupliquée (`main.dart:163-206` vs `385-435`) avec conditions divergentes. *(2 h)*
- **M17** `_themeMode` (state local) redondant avec le `ValueNotifier` static → risque de désync ; `initializeDateFormatting` appelé deux fois (`main.dart:38-39` puis `85-86`). *(1 h)*
- **M18** `_tryRefresh` utilise `http.post` global au lieu du `client` injectable → non mockable. *(0,25 h)*
- **M19** Chaînes/breakpoints/styles en dur (mois FR `dashboard:81-84`, `'Montréal'/'QC'`, breakpoints 1024/1280/720, `fontSize` inline) → centraliser. *(1-2 h)*

**Infra**
- **M20** `DEMO_MODE` passé aux conteneurs (`docker-compose.yml:50,93`) mais **jamais lu dans `src/`** → config morte (ou feature non implémentée). À retirer ou implémenter. *(0,25 h)*
- **M21** Images non épinglées : `cloudflared:latest`, `postgres:16-alpine` (major seul) → reproductibilité/supply-chain. *(0,25 h)*
- **M22** `flutter-web` sans `deploy.resources.limits.memory` (l'API en a une). *(0,1 h)*
- **M23** `./migrations:/docker-entrypoint-initdb.d` ne s'exécute qu'au **premier** init d'un volume vide ; les migrations ultérieures dépendent de `scripts/migrate.js`. Double mécanisme à clarifier pour éviter les divergences. *(0,5 h)*

---

## ✅ Bonnes pratiques (à conserver)

**Sécurité backend**
- Validation stricte des secrets au démarrage en prod : présence + longueur JWT ≥32, refus du wildcard CORS, `process.exit(1)` si manquant (`server.js:17-42`). Excellent.
- Aucun secret hardcodé ; générés via `openssl rand` au déploiement. `.env*` correctement gitignorés (seuls `.example`/`.template` versionnés).
- bcrypt (coût configurable, défaut 12) + `bcrypt.compare` partout (pas de timing attack mot de passe).
- helmet (CSP/HSTS/referrerPolicy en prod), CORS sur liste blanche, rate limiting différencié (login clé `ip:email`, register/changePassword 3/h, API globale).
- Rotation des refresh tokens + invalidation globale via `tokenVersion` au changement de mot de passe ; révocation au logout/désactivation.
- `passwordHash` systématiquement retiré des réponses (`sanitizeUser`). RBAC via `authorizeRole`, anti-auto-suppression.
- Signature Twilio vérifiée (SDK officiel, fail-closed en prod). Stack traces masquées en prod.

**Qualité backend**
- **Aucune injection SQL** : tous les `sql\`\`` passent les valeurs en paramètres Drizzle ; `DATE_TRUNC` via map whitelisté.
- Pas de mass-assignment (mapping explicite des champs partout) ; whitelist `allowedFields` sur `bulkUpdateLeads`.
- Error handler central robuste (mapping 23505/23503, JSON malformé, payload trop gros). Pagination cohérente (clamp 100, whitelist `sortBy`). Transitions d'état centralisées (leases/payments).

**Infra**
- Ports liés à `127.0.0.1` uniquement (postgres/api/web) ; accès public via Cloudflare Tunnel. Secrets en env avec `:?required`. Healthchecks, rotation des logs, backups quotidiens + rétention 30j, limite mémoire API.

**Frontend**
- Parsing JSON très défensif (`as Type?` + `?? défaut`, normalisation snake/camelCase, enums avec `orElse`).
- Disposal exhaustif des controllers dans tous les écrans principaux ; listener de thème correctement retiré (`main.dart:74`).
- Widgets d'état partagés (`ErrorState` mappe HTTP→FR, `EmptyState`, skeleton shimmer). Gestion `mounted` systématique dans les handlers d'action. URL de base relative `/api` (proxy nginx, pas d'URL http codée en dur). `userFacingMessage` centralisé. Confirmations avant actions destructives.

---

## Plan de remédiation recommandé

1. **Jour 1 (régressions bloquantes)** : C1 (refresh) + C2 (création bail) + C3 (algorithms JWT) → ~4 h. Corriger en priorité car ils cassent l'usage réel, et **corriger les tests qui les masquent**.
2. **Jour 2-3 (sécurité)** : C4 (signature+hash refresh), I1 (IDOR), I2 (webhooks fail-closed), I3 (`passwordHash`) → ~6,5 h.
3. **Semaine 1 (robustesse)** : C5 (cookie HttpOnly), C6 + I8-I13 (timeouts, mounted, parsing, validation) → ~14 h.
4. **Continu** : mineurs (code mort, infra, cosmétique) → ~12 h.
