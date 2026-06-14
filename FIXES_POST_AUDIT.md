# CORRECTIFS POST-AUDIT — ImmoGestion v3

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/. Branche: agent/spark/immogestion-v3.

## Contexte
Tu viens de faire l'audit (AUDIT_FINAL.md). Note: 8/10. Tu dois MAINTENANT corriger les 7 problèmes identifiés.

## CORRECTIFS MAJEURS (2)

### M1 — Secrets webhooks obligatoires en production
**Fichiers:** `services/api-backend/src/server.js` (ou le fichier qui monte les webhooks)
**Problème:** Les secrets `VAPI_WEBHOOK_SECRET` et `MARKETPLACE_WEBHOOK_SECRET` sont optionnels. En production, un webhook non signé = porte ouverte.
**Action:** Dans le middleware ou le contrôleur qui vérifie ces secrets, ajouter:
```js
if (process.env.NODE_ENV === 'production' && !process.env.VAPI_WEBHOOK_SECRET) {
  throw new Error('VAPI_WEBHOOK_SECRET required in production');
}
```
Faire la même chose pour MARKETPLACE_WEBHOOK_SECRET. Vérifier que le webhook Vapi dans `maintenance.service.js` (`ingestVapiWebhook`) valide le secret avant de traiter la requête.

### M2 — Aligner le contrat trends analytics
**Fichiers:** `services/api-backend/src/controllers/analytics.controller.js`
**Problème:** `occupancy-trend` et `revenue-trend` retournent `{data: [...]}` mais le frontend attend `{trends: [...]}`.
**Action:** Vérifier ce que le dashboard Flutter (`dashboard_screen.dart`) attend réellement, puis aligner le contrôleur. Si le dashboard attend `trends`, changer le contrôleur pour wrapper avec `{trends: data}`. Si le dashboard utilise déjà `data`, ne rien changer — le problème est peut-être un faux positif.

## CORRECTIFS MINEURS (5)

### m1 — Cache PlexFlow: ne pas stocker null sur échec
**Fichier:** `services/api-backend/src/services/plexflow.service.js`
**Problème:** `cachedGet()` stocke `null` dans le cache quand l'API échoue → TTL 1h de données vides.
**Action:** Modifier `cachedGet()` pour ne pas cacher quand `data` est null:
```js
if (data !== null) {
  cache.set(cacheKey, data, CACHE_TTL_SECONDS);
}
return data;
```

### m2 — Inclure qualificationState/qualificationNotes dans le CRUD lead
**Fichiers:** `services/api-backend/src/controllers/lead.controller.js` et `services/api-backend/src/config/validation-schemas.js`
**Problème:** Les champs `qualificationState` et `qualificationNotes` existent dans schema.js mais ne sont pas inclus dans le CRUD.
**Action:** Ajouter ces champs dans le schéma Joi de création/mise à jour des leads, et les inclure dans les opérations d'insertion/update du contrôleur.

### m3 — Nettoyer doc Swagger /leads
**Fichier:** `services/api-backend/src/routes/lead.routes.js`
**Problème:** Commentaires Swagger documentent des champs qui n'existent plus (supprimés dans le ménage).
**Action:** Parcourir les commentaires JSDoc/Swagger dans lead.routes.js et retirer les références aux champs/modules supprimés.

### m4 — Statut partiellement_reçu inatteignable
**Fichier:** `services/api-backend/src/services/renovation.service.js` ou `renovation.controller.js`
**Problème:** Le statut `partially_received` est défini mais aucune logique ne permet de l'atteindre.
**Action:** Ajouter une transition dans le contrôleur rénovation: quand on reçoit une commande partiellement, permettre de passer à `partially_received`.

### m5 — Code mort Flutter: _buildVacancySummary
**Fichier:** `lib/screens/dashboard_screen.dart`
**Problème:** `_buildVacancySummary()` appelle une API supprimée.
**Action:** Vérifier si la méthode existe encore, et si elle appelle une route supprimée. Si oui, retirer la méthode ou la remplacer par un appel à l'API PlexFlow.

## VÉRIFICATION FINALE
Après avoir corrigé les 7 problèmes:
1. `npm run lint` — 0 nouvelle erreur
2. `flutter analyze` — 0 nouvelle issue
3. Lister chaque problème corrigé avec le fichier modifié

## RÈGLES
- Lis chaque fichier avant de le modifier
- Ne casse rien d'existant
- Si un problème est un faux positif (ex: le contrat trends est déjà correct), dis-le explicitement
- Priorité: M1 > M2 > m1 > m2 > m3 > m4 > m5
