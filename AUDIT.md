# AUDIT COMPLET — ImmoGestion v3

Tu es un auditeur de code senior. Audite le projet ImmoGestion dans C:\Users\SimonGravel\ImmoGestion.

## Stack
- **Frontend** : Flutter Web (80 fichiers Dart dans lib/)
- **Backend** : Node.js/Express/Drizzle ORM + PostgreSQL (80 fichiers JS dans services/api-backend/src/)
- **Infra** : Docker Compose, Nginx, Cloudflare Tunnel

## Objectif
Trouver TOUTES les failles : sécurité, bugs, fuites mémoire, edge cases, code mort, mauvaises pratiques, problèmes de performance.

## Périmètre à inspecter

### Backend (priorité sécurité)
- `src/auth/` — JWT, middleware, tokens
- `src/controllers/` — validation, error handling, SQL injection
- `src/config/` — validation schemas, swagger
- `migrations/` — contraintes, index, colonnes manquantes
- `docker-compose.yml` — secrets, ports exposés
- `scripts/seed.js` — données seed

### Frontend (priorité qualité)
- `lib/services/api_service.dart` — HTTP client, error handling, tokens
- `lib/services/auth_service.dart` — auth flow, token storage
- `lib/screens/` — 20+ écrans, vérifier patterns communs
- `lib/widgets/` — composants réutilisables
- `lib/models.dart` — 1992 lignes, parsing JSON, null safety
- `lib/main.dart` — routing, thèmes, init

## Format du rapport

### 🔴 CRITIQUE — corriger immédiatement (sécurité, data loss, crash)
### 🟡 IMPORTANT — cette semaine (bugs, perf, edge cases)
### 🟢 MINEUR — nice to have (code mort, style, refactors)
### ✅ BONNES PRATIQUES — ce qui est bien fait

Chaque problème = **fichier:ligne + description + fix concret + effort estimé (h)**.

## Règles
- Lis les fichiers clés en entier + échantillon représentatif des écrans/controllers
- Rapport en français, actionnable
- Priorise la sécurité (auth, injection, secrets exposés, CORS, rate limiting)
- Vérifie les edge cases (null, empty, timeout, erreur réseau)
- Cherche le code mort (imports inutilisés, fonctions jamais appelées, dead code après refactors)
- Vérifie la cohérence des noms de colonnes entre migrations et controllers
