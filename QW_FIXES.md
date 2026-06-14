# Quick Wins ImmoGestion — 6 correctifs post-audit

Tu es Opus 4.8. Tu viens de faire l'audit d'ImmoGestion (rapport dans AUDIT_BRIEF.md). Maintenant tu dois CORRIGER les 6 quick wins identifiés. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/.

## Règles
- Lis chaque fichier avant de le modifier
- Corrige UNIQUEMENT ce qui est listé ci-dessous — ne fais pas d'autres changements
- Après chaque correction, vérifie que le code est syntaxiquement correct
- Backend: `npm run lint` doit passer (ou au moins ne pas introduire de nouvelles erreurs)
- Frontend Flutter: `flutter analyze` si possible
- Si un fix est déjà appliqué, dis-le et passe au suivant
- **Pas de commentaires** dans le code sauf si demandé
- **Langue** : français québécois pour les strings utilisateur, anglais pour le code

---

## QW1 — Signer les webhooks Twilio + Facebook

### Twilio (services/api-backend/src/services/twilio.service.js)
- Ajouter un middleware `twilio.webhook()` qui vérifie `X-Twilio-Signature` avec le SDK Twilio
- L'appliquer sur les routes SMS entrantes (chercher dans routes/ quelle route reçoit les webhooks Twilio)
- Si le SDK Twilio n'a pas de méthode intégrée, implémenter la vérification HMAC-SHA256 manuellement : `crypto.createHmac('sha256', authToken).update(url + params).digest('base64')` comparé au header

### Facebook (services/api-backend/src/services/facebook.service.js)
- Ajouter la vérification `X-Hub-Signature-256` : `crypto.createHmac('sha256', appSecret).update(rawBody).digest('hex')` → comparer à `sha256=...`
- L'appliquer sur la route Facebook Lead Ads / Messenger (chercher dans routes/)

---

## QW2 — Forcer rôle non-admin à l'inscription

### Fichier: services/api-backend/src/controllers/auth.controller.js
- Dans le handler `register`, forcer `role = 'user'` (ou 'member') au lieu de laisser le défaut `'admin'`
- Si le champ `role` est envoyé dans le body, l'ignorer (ne pas permettre à l'utilisateur de choisir son rôle)

### Fichier: services/api-backend/src/database/schema.js
- Changer la valeur par défaut de `role` de `'admin'` à `'user'` (colonne `users.role`)

---

## QW3 — Override obligatoire DEMO_USER_PASSWORD + brancher demoWriteGuard

### Fichier: services/api-backend/src/server.js
- Ajouter `demoWriteGuard` dans la chaîne de middleware (probablement après `auth`)
- Vérifier que `DEMO_USER_PASSWORD` est overridé en production (sinon refuser de démarrer si `DEMO_MODE=true`)

### Fichier: services/api-backend/src/controllers/demo.controller.js
- Si `DEMO_MODE=true` et `DEMO_USER_PASSWORD === 'Demo2025!'`, refuser le login démo (forcer un override)
- Optionnel : lire `DEMO_USER_PASSWORD` depuis une variable d'environnement

---

## QW4 — Bump axios + valider JWT_REFRESH_SECRET

### Fichier: services/api-backend/package.json
- Bump `axios` à la dernière version stable (≥1.7.x) dans `overrides` ou `resolutions` (vu que c'est une dépendance transitive de Twilio)
- Vérifier que `twilio` n'a pas déjà bumpé axios dans sa propre version

### Fichier: services/api-backend/src/config/jwt.config.js (ou équivalent)
- Ajouter validation de longueur minimale pour `JWT_REFRESH_SECRET` (≥32 caractères, comme `JWT_SECRET`)
- Refuser le démarrage si trop court en production

---

## QW5 — Supprimer helper SQL mort + fix /health

### Fichier: services/api-backend/src/utils/apiResponse.js
- Supprimer la fonction `addSearch()` (ligne ~99) — helper mort qui interpole des noms de colonnes

### Fichier: services/api-backend/src/server.js (ou contrôleur health)
- Le endpoint `/health` ne doit pas renvoyer `error.message` — remplacer par un message générique ou un status simple

---

## QW6 — Cache ciblé (remplacer invalidateAll par invalidation par clé)

### Fichier: services/api-backend/src/services/cache.service.js (backend)
- Ajouter une méthode `invalidate(pattern)` qui supprime seulement les clés matchant un pattern (ex: `buildings_*`)
- NE PAS supprimer `invalidateAll()` — certains appels légitimes peuvent en avoir besoin
- Ajouter `invalidate(pattern)` en plus, et l'utiliser dans les services

### Fichiers: lib/services/*.dart (frontend Flutter)
- Remplacer les appels à `CacheService.invalidateAll()` par `CacheService.invalidate('buildings_*')` (ou le pattern approprié)
- Pattern par domaine : `buildings_*`, `units_*`, `leases_*`, `payments_*`, `leads_*`, `visits_*`
- Chercher TOUS les appels à `invalidateAll()` dans `lib/services/` et les remplacer par le pattern spécifique au service

---

## Vérification finale
- `npm run lint` dans services/api-backend/ — doit passer
- `flutter analyze` dans lib/ — doit passer (ou au moins pas de nouvelles erreurs)
- Lister ce qui a été corrigé et ce qui n'a pas pu l'être (avec raison)
