# AUDIT COMPLET — ImmoGestion (Flutter/Supabase)

Tu es un auditeur de code senior spécialisé en Flutter/Dart et Supabase. Tu dois auditer le projet complet dans C:/Users/SimonGravel/ImmoGestion/.

## Contexte
ImmoGestion est l'app de **gestion locative** de Simon Gravel (propriétaire-bailleur, 61 portes, 7 immeubles, Sherbrooke QC). C'est une app Flutter (PWA/web) connectée à Supabase. Elle gère : bâtiments, logements, locataires, baux, paiements, entretien, communications SMS, visites, rénovations, employés, documents.

## Objectif
Auditer TOUT le projet pour que Spark (moi) se familiarise avec l'architecture et identifie les problèmes. Structure ton rapport comme ceci :

### 1. ARCHITECTURE GLOBALE
- Stack technique (Flutter version, packages clés, state management, DB)
- Arborescence des dossiers
- Routes / navigation
- Flux de données (auth → API → Supabase)

### 2. AUDIT SÉCURITÉ
- Auth (Supabase Auth? Magic link? JWT stocké comment?)
- RLS sur les tables Supabase
- Secrets / clés API exposées
- Validation des inputs

### 3. AUDIT BASE DE DONNÉES
- Tables Supabase (liste complète)
- Relations, index, contraintes
- Migrations SQL (21 fichiers)
- Cohérence avec le code Dart

### 4. AUDIT CODE DART (123 fichiers)
- Qualité du code (null safety, async/await, error handling)
- State management (quel pattern? Provider? Riverpod? setState?)
- Services (auth_service, api_service, building_service, etc.)
- Screens (40+ écrans — liste et fonction de chacun)
- Models (lib/models.dart)
- Code mort / duplication
- Performance (rebuilds inutiles, streams non disposés)

### 5. AUDIT FONCTIONNEL
- Features implémentées vs prévues
- UX/UI (Material Design? Custom?)
- Accessibilité
- Gestion d'erreurs utilisateur

### 6. PROBLÈMES IDENTIFIÉS
- 🔴 Critiques (sécurité, data loss, crashes)
- 🟡 Importants (performance, UX, bugs)
- 🟢 Mineurs (code style, optimisations)

### 7. COMPARAISON AVEC IMMOCRM
- Forces/faiblesses relatives
- Synergies possibles (partage de code, DB commune?)

### 8. RECOMMANDATIONS PRIORISÉES
- Quick wins (1-2h chacun)
- Chantiers moyens (4-8h)
- Long terme

## Règles
- Lis les fichiers clés : main.dart, app_config.dart, models.dart, auth_service.dart, api_service.dart, pubspec.yaml, AGENTS.md, les migrations SQL, et un échantillon représentatif de screens/services
- Ne lis pas TOUS les 123 fichiers Dart — échantillonne intelligemment (1 screen sur 3, tous les services, tous les models)
- Le rapport doit être en français
- Sois exhaustif sur la sécurité et l'architecture
- Format : markdown, sections claires, tableaux pour les listes
