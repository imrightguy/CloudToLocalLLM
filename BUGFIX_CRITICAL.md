# BUGFIX — 5 bugs critiques (C1, C3, C4, C5, C6)

Fixe ces 5 bugs dans C:\Users\SimonGravel\ImmoGestion. Lis chaque fichier avant de modifier. C2 ignoré (PlexFlow gère les baux).

## C1 — Refresh token TOUJOURS rejeté
**Fichier:** `services/api-backend/src/controllers/auth.controller.js:~289`
`user.tokenVersion !== tokenRecord.tokenVersion` — la table `refresh_tokens` n'a pas de colonne `token_version`, donc `tokenRecord.tokenVersion = undefined`, et `user.tokenVersion >= 1` → condition toujours vraie → 401.
**Fix:** Supprimer la comparaison tokenVersion (lignes 289-299). La rotation des tokens suffit.

## C3 — Confusion d'algorithme JWT / alg:none
**Fichier:** `services/api-backend/src/auth/jwt.middleware.js:~15,:52,:61,:67`
`jwt.verify(token, secret)` sans `{ algorithms: ['HS256'] }` → accepte tout algo.
**Fix:** Ajouter `{ algorithms: ['HS256'] }` à chaque `jwt.verify()` et `algorithm: 'HS256'` à chaque `jwt.sign()`.

## C4 — Refresh token jamais vérifié + stocké en clair
**Fichier:** `services/api-backend/src/controllers/auth.controller.js:~239-243`
Refresh token cherché par égalité string en DB, signature JWT jamais validée. Token en clair = dump SQL = vol de session.
**Fix:** (1) `jwt.verify(refreshToken, JWT_REFRESH_SECRET, {algorithms:['HS256']})` avant le lookup DB. (2) Stocker `crypto.createHash('sha256').update(token).digest('hex')` en DB, comparer le hash.

## C5 — JWT dans localStorage (XSS)
**Fichier:** `lib/services/auth_token_storage_web.dart:~39-55`
accessToken et refreshToken en clair dans localStorage → tout script injecté les vole.
**Fix:** Déplacer le refresh token vers un cookie HttpOnly/Secure/SameSite=Strict côté backend. Garder l'access token en mémoire seulement (variable, pas localStorage). Le endpoint `/auth/refresh` lit le cookie au lieu du body. Nécessite: modifier le endpoint refresh pour lire `req.cookies.refreshToken`, modifier le endpoint login pour set le cookie, ajouter `cookie-parser` au backend, modifier le frontend pour ne plus envoyer le refresh token dans le body.

## C6 — Controllers jamais disposés
**Fichiers:** `lib/screens/maintenance_screen.dart:~288-290` et `lib/screens/renovation_orders_screen.dart:~245-247`
TextEditingController créés dans _showCreateDialog() jamais disposés.
**Fix:** `showDialog(...).then((_) { c1.dispose(); c2.dispose(); c3.dispose(); })` ou convertir en StatefulWidget dédié.