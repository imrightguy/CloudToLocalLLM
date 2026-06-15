# TASK — Dashboard: piliers cliquables + navigation + états + retry

Tu es un développeur Flutter senior. Corrige et complète le dashboard d'ImmoGestion.

**Fichier principal:** C:\Users\SimonGravel\ImmoGestion\lib\screens\dashboard_screen.dart
**Fichiers à lire avant:** lib/main.dart (routes), lib/widgets/kpi_card.dart, lib/widgets/error_state.dart, lib/widgets/loading_state.dart, lib/widgets/empty_state.dart, lib/services/analytics_service.dart, lib/models.dart (PillarsOverview)

## PROBLÈMES ACTUELS
1. KPIs "Revenus" et "Taux d'occupation" → onTap: () {} (vide, rien ne se passe)
2. KPI "Pistes ouvertes" → navigue vers /communications au lieu de /leads
3. Les 3 piliers naviguent mais sans filtre pré-appliqué
4. Boutons "Réessayer" incohérents (parfois aucun appel réseau)
5. Pas de gestion d'erreur par section (une erreur bloque toute la page)
6. Pas de skeleton différencié par section

## CORRECTIONS DEMANDÉES

### 1. Brancher TOUS les KPIs et piliers aux bonnes routes

| Élément | Route | Filtre |
|---|---|---|
| KPI "Revenus" | /payments | aucun |
| KPI "Taux d'occupation" | /buildings | aucun |
| KPI "Baux actifs" | /leases | aucun (déjà OK) |
| KPI "Pistes ouvertes" | /leads | aucun (corrige /communications → /leads) |
| Pilier "Leasing" | /leads | aucun |
| Pilier "Maintenance" | /maintenance-tickets | aucun |
| Pilier "Rénovation" | /renovation-ops | aucun |

### 2. Rendre chaque carte ENTIÈREMENT cliquable
- Curseur pointer au survol (MouseRegion ou InkWell)
- Effet hover (élévation légère ou teinte)
- Ripple au tap
- Même si valeur = 0, la carte reste cliquable
- Semantic label: "Voir les X tâches bloquées" etc.

### 3. Gestion d'erreur par section (CRITIQUE)
Actuellement si UN appel échoue, TOUTE la page est en erreur.
**Fix:** Chaque section (KPIs, piliers, pipeline, visites, buildings, activité, vacances) doit:
- Charger indépendamment
- Afficher sa PROPRE erreur avec son PROPRE bouton "Réessayer"
- Ne pas bloquer les autres sections

Implémente un pattern: pour chaque section, un widget stateful qui gère son propre loading/error/data.
Ou utilise un `_SectionLoader<T>` widget générique.

### 4. Boutons "Réessayer" 100% fonctionnels
Chaque bouton "Réessayer" doit:
- Remettre la section en état "chargement" (skeleton)
- Relancer RÉELLEMENT l'appel réseau (pas juste cacher l'erreur)
- Afficher un message adapté: "Timeout réseau" vs "Erreur serveur (503)" vs "Erreur inconnue"

### 5. États de page obligatoires
Sur le dashboard ET chaque page de destination:
1. **Chargement:** skeleton/shimmers (pas écran vide)
2. **Succès:** données normales
3. **Vide:** EmptyState avec message clair + action si pertinent
4. **Erreur:** ErrorState avec message lisible + bouton "Réessayer" fonctionnel

### 6. Navigation & retour
- Le bouton retour (flèche) doit fonctionner sur toutes les pages
- Vérifie que les pages de destination ont un AppBar avec leading back button
- La société active ne doit pas être reset pendant la navigation

## CONTRAINTES
- Thème sombre, composants existants
- Responsive (mobile + desktop)
- Routes existantes dans main.dart (MaterialPageRoute via pushNamed)
- NE MODIFIE PAS le backend
- flutter analyze doit passer avec 0 erreur
- NE CASSE PAS les fonctionnalités existantes

## ÉTAPES
1. Lis dashboard_screen.dart en entier
2. Lis main.dart pour les routes disponibles
3. Lis kpi_card.dart pour voir si InkWell/onTap est déjà supporté
4. Lis error_state.dart pour voir l'API du widget
5. Refactorise le dashboard pour le chargement par section
6. Branche tous les onTap manquants
7. Vérifie avec flutter analyze