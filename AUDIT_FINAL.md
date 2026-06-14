# AUDIT COMPLET — ImmoGestion v3 (Post-Travaux)

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/. Branche: agent/spark/immogestion-v3, commit a0c0797.

## Contexte
Un agent (Spark) a effectué un ménage et une refonte majeure du projet. Tu dois auditer TOUT le travail pour vérifier la qualité, la cohérence, et identifier les problèmes.

## Ce qui a été fait (selon Spark)
1. 6 quick wins sécurité (webhooks signés, auth forcée non-admin, demo protégée, axios bump, cache ciblé, nettoyage SQL)
2. Suppression ~40 fichiers modules non essentiels (Marketplace, Pipeline, Onboarding, Démo, Documents, Dossiers TAL, Tenant checklist, WhatsApp, Messenger, Facebook, Email, Weekly report)
3. Migration 021_drop_unused_modules.sql (12 tables obsolètes) — appliquée
4. Migration 022_add_maintenance_tickets.sql — appliquée
5. Dashboard 3 piliers (Leasing, Maintenance, Rénovation) — déjà existant
6. Module Leasing: service leasing.service.js, intégration Hermes (hermes_service.dart)
7. Module Maintenance: maintenance.service.js, maintenance_screen.dart, maintenance_ticket_detail.dart, webhook Vapi
8. Module Rénovation: renovation_orders_screen.dart, renovation_service.dart
9. Module PlexFlow: plexflow.service.js, plexflow.controller.js, plexflow.routes.js, plexflow_service.dart
10. Nettoyage tests: 9 fichiers de test supprimés (références aux modules supprimés)

## Vérifications passées
- npm run lint: 0 erreur (71 warnings pré-existants)
- flutter analyze: 0 issue
- flutter build web: réussi (64s)

## TA MISSION
Audite CHAQUE fichier modifié/créé. Ne te fie pas aux dires de Spark — vérifie tout toi-même.

### Phase 1 — Audit des nouveaux fichiers (qualité du code)
Lis chaque nouveau fichier et vérifie:
- imports corrects (pas d'imports vers des fichiers supprimés)
- cohérence avec le schema.js (colonnes, types)
- gestion d'erreurs (try/catch, logger)
- pas de code mort, pas de TODO, pas de console.log
- validation des entrées (Joi ou manuelle)
- français québécois pour les strings UI

Fichiers à auditer:
- services/api-backend/src/services/leasing.service.js
- services/api-backend/src/services/maintenance.service.js
- services/api-backend/src/services/plexflow.service.js
- services/api-backend/src/controllers/plexflow.controller.js
- services/api-backend/src/routes/plexflow.routes.js
- services/api-backend/src/routes/maintenance.routes.js
- services/api-backend/migrations/021_drop_unused_modules.sql
- services/api-backend/migrations/022_add_maintenance_tickets.sql
- lib/screens/leads_screen.dart
- lib/screens/maintenance_screen.dart
- lib/screens/maintenance_ticket_detail.dart
- lib/screens/renovation_orders_screen.dart
- lib/services/hermes_service.dart
- lib/services/plexflow_service.dart
- lib/services/renovation_service.dart
- lib/services/maintenance_service.dart

### Phase 2 — Audit des suppressions (vérifier qu'il n'y a pas de références résiduelles)
- Cherche TOUTES les références aux modules supprimés dans le code restant
- Vérifie que les imports dans server.js/routes/index.js ne pointent plus vers des fichiers supprimés
- Vérifie que les modèles Drizzle (schema.js) ne référencent plus de tables supprimées
- Vérifie que les contrôleurs restants n'appellent pas de services supprimés

### Phase 3 — Audit de cohérence
- Vérifie que les nouvelles routes sont bien montées dans server.js ou routes/index.js
- Vérifie que les nouveaux services sont exportés et utilisés correctement
- Vérifie que le dashboard Flutter appelle bien les bonnes APIs
- Vérifie que les modèles Flutter (models.dart) correspondent aux colonnes DB

### Phase 4 — Audit de sécurité
- Vérifie que les webhooks sont signés (Twilio, Vapi)
- Vérifie que les secrets ne sont pas en dur dans le code
- Vérifie que l'auth JWT est appliquée sur les routes sensibles
- Vérifie que les nouvelles routes ont des schémas de validation

## Format du rapport
Pour chaque problème trouvé:
- Sévérité: CRITIQUE / MAJEUR / MINEUR
- Fichier concerné
- Description précise
- Correctif proposé

Termine par un verdict global et une note sur 10.

## Règles
- Lis chaque fichier avant de juger
- Si un fichier n'existe pas, dis-le explicitement
- Ne suppose rien — vérifie
- Sois critique — Spark a codé manuellement, il peut y avoir des erreurs
