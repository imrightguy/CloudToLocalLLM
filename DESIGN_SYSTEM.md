# ImmoGestion — Design System v3

SaaS immobilier B2B. Interface épurée, crédible, premium.

## Palette

| Token | Light | Dark | Usage |
|---|---|---|---|
| `primary` | `#4F46E5` (indigo) | `#818CF8` | Actions, liens, accent principal |
| `primaryContainer` | `#E0E7FF` | `#1E1B4B` | Surfaces accentuées |
| `secondary` | `#6B7280` | `#9CA3AF` | Texte secondaire, icônes |
| `background` | `#F9FAFB` | `#0F172A` | Fond de page |
| `surface` | `#FFFFFF` | `#1E293B` | Cartes, conteneurs |
| `surfaceVariant` | `#F3F4F6` | `#334155` | Surfaces alternatives |
| `border` | `#E5E7EB` | `#1E293B` | Séparateurs, bordures |
| `success` | `#16A34A` | `#4ADE80` | Paiements, occupation |
| `warning` | `#D97706` | `#FBBF24` | Alertes, attention |
| `error` | `#DC2626` | `#F87171` | Erreurs, retards |
| `info` | `#4F46E5` | `#818CF8` | Information neutre |

## Typographie

| Niveau | Taille | Poids | Usage |
|---|---|---|---|
| `displayLarge` | 32px | 700 | Titre de page |
| `headlineMedium` | 24px | 600 | En-tête de section |
| `titleLarge` | 18px | 600 | Titre de carte |
| `bodyLarge` | 16px | 400 | Corps de texte |
| `bodyMedium` | 14px | 400 | Texte standard |
| `labelLarge` | 13px | 500 | Labels, métadonnées |
| `labelSmall` | 11px | 600 | Badges, chips |

Police : **Inter** (via Google Fonts). Fallback : système.

## Espacement

| Token | Valeur | Usage |
|---|---|---|
| `xs` | 4px | Micro-gap |
| `sm` | 8px | Gap interne |
| `md` | 16px | Gap standard |
| `lg` | 24px | Gap de section |
| `xl` | 32px | Gap large |
| `xxl` | 48px | Séparation majeure |

## Rayons d'angle

| Token | Valeur | Usage |
|---|---|---|
| `radiusSm` | 6px | Chips, petits conteneurs |
| `radiusMd` | 10px | Cartes, inputs |
| `radiusLg` | 14px | Modales, sheets |
| `radiusFull` | 999px | Pills, badges |

## Composants

### StatusBadge
Pill coloré avec label + icône optionnelle. 5 variants : success, warning, danger, info, neutral. Adaptatif clair/sombre.

### KpiCard
Carte horizontale scrollable : icône + valeur + trend + label. 140px hauteur.

### PillarCard
Carte verticale : icône dans conteneur accentué + titre + 3 métriques clé/valeur.

### DashboardSkeleton / ListSkeleton
Shimmer animé (gradient horizontal, 1200ms loop). Mime la forme du contenu réel.

### ErrorState
Icône + titre + description user-friendly + bouton Réessayer. Détecte `ApiException.statusCode` pour message contextualisé.

### EmptyState
Icône + titre + sous-titre + CTA optionnel.

## Modes

- **Clair** : fond `#F9FAFB`, cartes `#FFFFFF`, bordures `#E5E7EB`
- **Sombre** : fond `#0F172A`, cartes `#1E293B`, bordures `#1E293B`
- **Détection** : `ThemeMode.system` — suit le réglage OS automatiquement

## Accessibilité

- Contraste minimum 4.5:1 (WCAG AA) sur tout texte
- Cibles tactiles ≥ 44px (Material guidelines)
- Focus visible sur tous les inputs
- Labels textuels sur toutes les icônes (Tooltip)
