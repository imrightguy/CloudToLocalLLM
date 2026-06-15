# ImmoGestion — Redesign UI complet (SaaS immobilier B2B premium)

## Contexte

Tu travailles sur **ImmoGestion**, une app Flutter Web de gestion locative B2B (53+ portes, Sherbrooke QC). L'app est fonctionnelle backend (Node/Express/PostgreSQL/Drizzle, tous les endpoints répondent) mais le frontend a besoin d'un redesign complet pour passer de « prototype fonctionnel » à « SaaS professionnel ».

## Stack
- **Frontend :** Flutter Web 3.41.6, Material 3, packages `http`, `shared_preferences`, `intl`
- **Design actuel :** dark theme zinc/indigo, palette déjà définie dans `lib/theme/app_colors.dart`, espacement dans `lib/theme/app_spacing.dart`, typographie dans `lib/theme/app_typography.dart`
- **API :** `apiBaseUrl = '/api'` (proxy nginx vers backend Docker)
- **Assets :** Police Inter via Google Fonts (chargée dans `index.html`)
- **Pas de Riverpod/Bloc** — state management manuel (setState + services singleton)

## Architecture des fichiers
- `lib/main.dart` — MaterialApp, thème, routes nommées, AuthGate, navigation guard
- `lib/screens/home_screen.dart` — NavigationRail (desktop) + BottomNav (mobile), 5 onglets (Accueil, Tableau, Messages, Calendrier, Plus), le FAB violet causant le chevauchement est dans `dashboard_screen.dart`
- `lib/screens/dashboard_screen.dart` — KPI cards, pillars, pipeline, lead funnel, building perf, FAB violet "Nouvelle piste"
- `lib/screens/buildings_screen.dart` — Liste d'immeubles avec search, cartes, placeholder "prochaine version"
- `lib/screens/leases_screen.dart` — Liste de baux avec filtres, search
- `lib/screens/leads_screen.dart` — Pistes avec stage filter, search
- `lib/screens/payments_screen.dart` — Paiements
- `lib/theme/app_colors.dart` — Palette complète (primary=#6366F1 indigo, surfaces zinc, semantic colors)
- `lib/theme/app_spacing.dart` — Échelle d'espacement, radius, ombres, cardDecoration
- `lib/theme/app_typography.dart` — Styles texte (pageTitle, sectionHeader, kpiValue, body, caption...)
- `lib/widgets/` — kpi_card.dart, immo_app_bar.dart, trend_indicator.dart, lead_funnel.dart, building_perf_row.dart, revenue_chart.dart, occupancy_chart.dart
- `lib/services/api_service.dart` — Client HTTP singleton avec JWT, retry 401, ApiException
- `lib/models.dart` — Tous les modèles de données, enums (LeadStage, LeaseStatus, etc.)
- `lib/app_config.dart` — apiBaseUrl='/api', companyId

## Objectifs — À faire IMPÉRATIVEMENT

### 1. DESIGN SYSTEM — Palette cohérente + thème clair/sombre
- Conserver la palette indigo/zinc existante (elle est bonne)
- Ajouter un **thème clair** complet (actuellement seul le dark existe). Définir `_buildLightTheme()` dans `main.dart` avec des couleurs claires cohérentes (surfaces blanc/zinc-50, texte zinc-900, etc.)
- S'assurer que `AppColors` a des variantes claires utilisables OU définir un `ColorScheme` Material 3 complet pour les deux modes
- Typographie : hiérarchiser avec les styles existants (AppTypography.pageTitle, sectionHeader, body, caption) — les utiliser SYSTÉMATIQUEMENT dans tous les écrans au lieu de `TextStyle(fontSize: 14)` en dur
- Rayons d'angle : utiliser `AppSpacing.radiusSm/Md/Lg/Card/Control` partout — remplacer les `BorderRadius.circular(12)` et `20` en dur
- Accessibilité : contrastes WCAG AA minimum, tailles de cible tactile ≥48px

### 2. CORRECTION FAB — Widget flottant violet qui chevauche
Le FAB "Nouvelle piste" dans `dashboard_screen.dart` (lignes 98-109) est un `FloatingActionButton.extended` violet. Il chevauche les boutons d'action et le contenu en bas de l'écran.

**Fix attendu :**
- Remplacer le FAB par un bouton intégré dans l'AppBar ou dans le flux normal
- OU : ajouter un padding bottom suffisant au `SingleChildScrollView` pour que le contenu ne passe jamais sous le FAB
- OU : n'afficher le FAB qu'en mobile, et le remplacer par un bouton dans la barre d'actions en desktop
- Le FAB ne doit JAMAIS recouvrir du contenu interactif

### 3. SKELETONS + ÉTATS D'ERREUR ÉLÉGANTS
Créer des widgets réutilisables dans `lib/widgets/` :
- **`LoadingState`** — skeleton loader animé (shimmer ou pulse) qui mime la forme du contenu à charger. Pas juste un `CircularProgressIndicator`.
  - Variante `DashboardSkeleton` : 4 rectangles KPI + 2 larges rectangles pour les graphiques
  - Variante `ListSkeleton` : N rangées avec avatar rond + 2 lignes de texte
- **`ErrorState`** — icône + titre + description + bouton "Réessayer" + bouton "Diagnostiquer" (optionnel). Message user-friendly, pas le `e.toString()` brut.
  - Détecter le type d'erreur : 503 → "Service temporairement indisponible", 401 → "Session expirée", 500 → "Erreur serveur", réseau → "Vérifiez votre connexion"
- **`EmptyState`** — icône + titre + description + call-to-action (ex: "Ajouter un immeuble"). Distinct visuellement de l'état d'erreur.
- Remplacer **TOUS** les `if (_isLoading) CircularProgressIndicator()` et `if (_errorMessage != null) Text(_errorMessage!)` dans CHAQUE écran par ces widgets.

### 4. ÉCRANS DE LISTE — Cartes professionnelles + CRUD complet
Pour chaque écran de liste (Buildings, Leases, Leads, Payments, Employees, Communications) :
- **Badges de statut** : utiliser des `Chip` ou `Container` avec couleur sémantique (succès=vert, warning=orange, erreur=rouge, info=indigo) — pas juste du texte
- **En-têtes clairs** : compteur ("12 immeubles"), boutons de filtre visuellement distincts
- **Cartes** : cohérentes avec `AppSpacing.cardDecoration()`, ombre subtile, hover effect sur desktop
- **CRUD fonctionnel** : remplacer les `AlertDialog("prochaine version")` par des vrais formulaires
  - `buildings_screen.dart` ligne 81-96 : remplacer le placeholder par une `showModalBottomSheet` ou `showDialog` avec formulaire (nom, adresse, type, nombre d'unités, description) → POST `/buildings`
  - `leases_screen.dart` : bouton "+" → `LeaseFormScreen` existant (déjà lié), vérifier qu'il fonctionne
  - `leads_screen.dart` : bouton "+" → formulaire dans un dialog (nom, prénom, téléphone, courriel, source) → POST `/leads`
- **Pull-to-refresh** : `RefreshIndicator` sur tous les écrans de liste (déjà présent sur certains, standardiser)
- **Pagination ou chargement infini** : si plus de 50 éléments, scroll infini

### 5. TABLEAU DE BORD — Grille responsive avec vrais widgets
- Les KPI cards (`KpiCard`) fonctionnent déjà bien visuellement, mais :
  - Les organiser en grille responsive : 4 colonnes sur desktop large, 2 sur tablette, 1 sur mobile
  - Ajouter padding bottom suffisant (cf. problème FAB)
- Widget `BuildingPerformanceCard` : vérifier qu'il s'affiche correctement avec les données réelles
- Widget `LeadFunnelCard` : utiliser `AppSpacing` et `AppColors` au lieu de valeurs en dur
- Section "Piliers" (Leasing/Maintenance/Rénovation) : utiliser `AppTypography.sectionHeader` + icônes + couleurs sémantiques

### 6. BARRE LATÉRALE (NavigationRail) — Polie et moderne
- Les icônes et labels sont déjà fonctionnels mais :
  - Indicateur de sélection plus visible (barre latérale indigo au lieu de juste changer la couleur)
  - Icône "Plus" → dernier onglet qui ouvre le menu overflow
  - Logo "ImmoGestion" : utiliser l'icône apartment + texte, centré proprement
  - Ajouter l'avatar utilisateur en bas (récupéré via `AuthService` ou `ApiService.getProfile`)
  - Version compacte (icônes seules, <1024px), version étendue (icônes + labels, ≥1280px)
  - Tooltip sur chaque icône en mode compact

### 7. RESPONSIVE — Mobile/Tablette/Desktop
- Desktop ≥1280px : NavigationRail étendu + contenu en grille
- Desktop ≥1024px : NavigationRail compact + contenu en grille adaptée
- Tablette/Mobile <1024px : BottomNavigationBar + contenu en liste verticale single-column
- **Breakpoints** : utiliser `LayoutBuilder` (déjà fait dans `home_screen.dart`), appliquer les mêmes breakpoints dans chaque écran
- **Padding** : `EdgeInsets.symmetric(horizontal: max(AppSpacing.lg, (screenWidth - 1200) / 2))` pour centrer le contenu sur grands écrans
- **SafeArea** : toujours respecter les zones de sécurité (notch, home indicator) — déjà ok via `Scaffold`

## Ce que tu NE dois PAS changer
- `api_service.dart` — le client HTTP fonctionne, ne touche pas au JWT/refresh/retry
- `models.dart` — les modèles de données sont corrects (sauf si tu as besoin d'ajouter un modèle manquant pour un formulaire)
- `app_config.dart` — déjà patché à `/api`
- Les services (`*_service.dart`) — ils marchent, concentre-toi sur le frontend
- `main.dart` — la structure de navigation et les routes (sauf ajout du thème clair)

## Exécution
1. Lis les fichiers concernés AVANT de les modifier (ne fais pas d'hypothèses)
2. Fais les changements par lot logique (ex: d'abord les widgets d'état → puis les remplacer → puis le dashboard)
3. Après CHAQUE lot, exécute `flutter analyze` dans le répertoire racine pour vérifier
4. Si `flutter analyze` passe, commit immédiatement
5. Le thème clair peut être fait en dernier

Livrable attendu : tous les changements de code dans les fichiers Dart, avec `flutter analyze` qui passe à zéro erreur.
