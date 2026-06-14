# DESIGN SYSTEM — ImmoCRM → ImmoGestion

Tu es Opus 4.8. Tu travailles dans C:/Users/SimonGravel/ImmoGestion/. Branche: agent/spark/immogestion-v3.

## Objectif
Appliquer le design system d'ImmoCRM (zinc/slate/indigo, sobre, professionnel, inspiré Linear/Vercel) à toute l'interface Flutter d'ImmoGestion. Supprimer tout style Material Design coloré ou enfantin (teal, couleurs vives).

## Design System CIBLE (ImmoCRM)

ImmoCRM utilise Tailwind avec ce design system sombre :
```
Surfaces : zinc-950 (page) > zinc-900 (carte) > zinc-800 (inset)
Bordures : zinc-800 (défaut) / zinc-700 (forte, hover)
Texte    : zinc-100 (titre) / zinc-200 (corps) / zinc-400 (secondaire) / zinc-500 (muet)
Accent   : indigo-500 (#6366f1) — action principale
           amber (chaud), emerald (succès), red (danger), violet (à confirmer)
Police   : Inter
```

## Ce que tu dois faire

### 1. RÉÉCRIRE `lib/theme/app_colors.dart` — Palette zinc/slate/indigo

**Mode SOMBRE (principal, comme ImmoCRM) :**
```
Fond de page    : zinc-950  #09090b
Fond carte      : zinc-900  #18181b
Fond inset      : zinc-800  #27272a
Bordure défaut  : zinc-800  #27272a
Bordure forte   : zinc-700  #3f3f46
Texte primaire  : zinc-100  #f4f4f5
Texte secondaire: zinc-400  #a1a1aa
Texte muet      : zinc-500  #71717a
Accent (action) : indigo-500 #6366f1
Accent hover    : indigo-400 #818cf8
Succès          : emerald-500 #10b981
Avertissement   : amber-500  #f59e0b
Erreur          : red-500    #ef4444
Info            : indigo-400 #818cf8
```

**Mode CLAIR (sobre, professionnel) :**
```
Fond de page    : slate-50   #f8fafc
Fond carte      : white      #ffffff
Fond inset      : slate-100  #f1f5f9
Bordure défaut  : slate-200  #e2e8f0
Bordure forte   : slate-300  #cbd5e1
Texte primaire  : slate-900  #0f172a
Texte secondaire: slate-500  #64748b
Texte muet      : slate-400  #94a3b8
Accent (action) : indigo-600 #4f46e5
Accent hover    : indigo-500 #6366f1
Succès          : emerald-600 #059669
Avertissement   : amber-600  #d97706
Erreur          : red-600    #dc2626
Info            : indigo-500 #6366f1
```

**Supprimer TOUT ce qui est teal :**
- `primary`, `primaryLight`, `primarySurface` → remplacer par indigo
- `chartLine1`, `chartLine2`, `chartBar`, `chartBarHighlight`, `chartArea` → remplacer par indigo/zinc
- `funnelNouveau` à `funnelBailSigne` → remplacer par palette zinc/indigo sobre
- `skyBlue` → remplacer par indigo tint
- `stageNouveau` à `stageBailSigne` → remplacer par palette sobre
- `visitConfirmed`, `visitCompleted`, etc. → garder mais ajuster aux nouvelles couleurs
- `rankGold`, `rankSilver`, `rankBronze` → garder (métaux, intemporels)

**Garder les noms de constantes** pour ne pas casser les imports dans les 30+ fichiers qui utilisent `AppColors.primary`, `AppColors.success`, etc. Change juste les valeurs hex.

### 2. RÉÉCRIRE `lib/main.dart` — Thèmes

**Supprimer `primarySwatch: Colors.teal`** dans les deux thèmes. Remplacer par `colorSchemeSeed: AppColors.primary` (indigo).

**Thème CLAIR :**
```dart
ThemeData(
  colorSchemeSeed: AppColors.primary,
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: AppTypography.fontFamily,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: AppColors.surface,
  ),
  cardTheme: CardThemeData(
    elevation: 0,  // Linear/Vercel style — flat cards with border, not shadow
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
)
```

**Thème SOMBRE :**
```dart
ThemeData(
  colorSchemeSeed: AppColors.primary,
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: AppTypography.fontFamily,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: AppColors.surface,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  ),
  dividerTheme: DividerThemeData(
    color: AppColors.border,
    thickness: 1,
  ),
)
```

### 3. METTRE À JOUR `lib/theme/app_spacing.dart`

Ajouter les radius Linear-style :
```dart
static const double radiusControl = 6.0;  // boutons, inputs
static const double radiusCard = 8.0;     // cartes
static const double radiusOverlay = 12.0; // modales, dropdowns
```

Remplacer `elevationCard` et `elevationCardHover` par des ombres plus subtiles (Linear style) ou les supprimer (cartes flat avec border).

### 4. SUPPRIMER tout style enfantin dans les widgets

Parcours ces fichiers et supprime/remplace :
- **`lib/widgets/kpi_card.dart`** — remplacer les couleurs vives par indigo/zinc sobre
- **`lib/widgets/lead_funnel.dart`** — remplacer les couleurs funnel arc-en-ciel par dégradé indigo
- **`lib/widgets/building_perf_row.dart`** — vérifier les couleurs
- **`lib/widgets/immo_app_bar.dart`** — vérifier qu'il utilise `AppColors.surface` et `AppColors.textPrimary`
- **`lib/screens/dashboard_screen.dart`** — vérifier `_buildPillarsSection` (les couleurs accent des 3 piliers)
- **`lib/screens/leads_screen.dart`** — vérifier les badges de statut
- **`lib/screens/maintenance_screen.dart`** — vérifier les badges urgence/statut

### 5. VÉRIFICATION

Après toutes les modifications :
1. `flutter analyze` — 0 nouvelle erreur
2. `flutter build web` — réussi
3. Liste chaque fichier modifié avec un résumé des changements

## RÈGLES
- Lis chaque fichier avant de le modifier
- Ne casse rien d'existant
- Garde les noms de constantes AppColors — change juste les valeurs
- Pas de commentaires dans le code
- Si un widget utilise une couleur en dur (ex: `Color(0xFF0F766E)`), remplace par la constante AppColors appropriée
