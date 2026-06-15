# REFONTE UX — Centre de maintenance ImmoGestion

Tu es un designer UI/UX senior spécialisé Flutter. Refais l'écran Centre de maintenance selon les spécifications ci-dessous.

**Fichier principal:** C:\Users\SimonGravel\ImmoGestion\lib\screens\maintenance_command_center_screen.dart
**Fichiers secondaires (lis avant):** lib/theme/app_colors.dart, lib/theme/app_spacing.dart, lib/widgets/immo_app_bar.dart, lib/widgets/loading_state.dart, lib/widgets/error_state.dart, lib/widgets/empty_state.dart, lib/services/maintenance_service.dart

## PROBLÈMES ACTUELS
- Grille uniforme de 12 KPIs — impossible de distinguer urgent vs anecdotique
- Beaucoup de "0" = bruit visuel
- KPIs non cliquables — informent sans mener à l'action
- Cartes de propriétés répétitives et verbeuses (4 lignes "Capacité", 3 lignes "Prochain jalon")
- Remplies de "0" et "—"
- Pas de recherche, tri, filtre
- Jargon ambigu ("Dispatchables", "0/0 SMS")
- Hiérarchie typographique plate

## AMÉLIORATIONS DEMANDÉES

### 1. Hiérarchiser les KPIs
Remplace la grille de 12 par 3-4 KPIs prioritaires en avant:
- Tâches en retard (rouge si >0)
- Bloqués (orange si >0)  
- Demandes en cours (bleu)
- Dispatchables (vert si =0, jaune si >0)

Code couleur sémantique. Regroupe les KPIs secondaires dans une section repliable (ExpansionTile) ou une ligne compacte en bas. Masque/atténue les KPIs à 0.

### 2. KPIs actionnables
Chaque KPI prioritaire est cliquable → filtre la liste des propriétés en dessous.
Ajoute un indicateur visuel (chevron, ripple, hover) pour montrer que c'est cliquable.
Ajoute un chip/badge "Filtre actif: Bloqués" avec un X pour annuler le filtre.

### 3. Simplifier les cartes de propriétés
Affiche d'abord l'essentiel: adresse, nb d'unités, badge du statut le plus critique.
Permets d'étendre (ExpansionTile ou onTap → expansion) pour voir le détail.
Masque les champs vides ("—", "0") — ne les affiche pas.
Badges seulement pour valeurs non nulles.

### 4. Recherche, tri, filtres
Barre de recherche par adresse en haut.
Tri: par tâches en retard (défaut), par échéance, par nom.
Filtres rapides: "À traiter" (retard + bloqués), "Bloqué", "Tout".
Propriétés avec actions en haut de liste.

### 5. Vocabulaire et hiérarchie visuelle
Remplace "Dispatchables" → "Tâches prêtes" avec tooltip.
Remplace "0/0 SMS" → "Messages" avec tooltip.
Hiérarchie typographique: titres > sous-titres > valeurs.
Espacement augmenté pour aérer.

### 6. États vides et chargement
EmptyState: "Aucune propriété ne nécessite d'action" + illustration.
Skeleton loading (shimmer) au lieu d'un spinner.

## CONTRAINTES
- Thème sombre (AppColors existant)
- Composants Flutter existants (ImmoAppBar, ErrorState, EmptyState, LoadingState)
- Responsive (mobile + desktop)
- Pas de nouvelles données — utilise ce que maintenance_service.dart expose déjà
- NE MODIFIE PAS le backend ni les services
- flutter analyze doit passer avec 0 erreur

## ÉTAPES
1. Lis maintenance_command_center_screen.dart en entier
2. Lis maintenance_service.dart pour voir les données disponibles
3. Lis app_colors.dart et app_spacing.dart
4. Refais l'écran complètement
5. Vérifie avec flutter analyze