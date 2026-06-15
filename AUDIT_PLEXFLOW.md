# AUDIT — PlexFlow API integration (backend + frontend)

Audite et corrige TOUS les bugs dans l'intégration PlexFlow de ImmoGestion.
Fichiers: C:\Users\SimonGravel\ImmoGestion\services\api-backend\src\services\plexflow.service.js
         C:\Users\SimonGravel\ImmoGestion\services\api-backend\src\services\plexflow-ingestion.service.js
         C:\Users\SimonGravel\ImmoGestion\lib\services\plexflow_service.dart
         C:\Users\SimonGravel\ImmoGestion\lib\screens\plexflow_gap_screen.dart

## CONTEXTE CRITIQUE — API PlexFlow réelle

L'API PlexFlow a UN SEUL endpoint REST: GET /property/vacant-units
URL: https://api.plexflow.ca/api/public
Auth: X-Plexflow-Key (pas Bearer)

La réponse contient 55 unités avec CES CHAMPS RÉELS (38 champs par unité):
- unitId, unitNickname, unitAddress, apptNb, floorLevel, surfaceArea, unitType
- propertyId, propertyNickname, propertyAddress, propertyAddressDetails
- rentId, rentStatus, currentRentTotalCents (EN CENTS! 84500 = 845.00$), scheduledRentTotalCents, rentBeforeDiscount, marketPrice, marketRenewalPrice
- tenantsLeaving, tenantsEntering, dateTenantLeaving, dateTenantEntering, markedWontRenew
- statuses, dateAvailableForMaintenance, dateAvailableForRent
- subaccount

## BUGS CONNUS

### BUG 1 — Montants en cents non convertis
Le code utilise pick(unit, ['rent', 'rentAmount', 'monthlyRent']) — ces champs N'EXISTENT PAS dans PlexFlow.
Le vrai champ est currentRentTotalCents (en cents). 84500 = 845.00$, pas 84500$.
**Fix:** Lire currentRentTotalCents et diviser par 100. Idem pour scheduledRentTotalCents, rentBeforeDiscount, marketPrice, marketRenewalPrice.

### BUG 2 — getBuildings() appelle /buildings (n'existe pas)
L'API PlexFlow n'a qu'un seul endpoint: /property/vacant-units.
getBuildings(), getUnits(), getLeases() doivent TOUS dériver de vacant-units.
**Fix:** Remplacer getBuildings/getUnits/getLeases par des fonctions qui extraient les données de vacant-units.

### BUG 3 — getFullSnapshot() probablement cassé
Dépend de getBuildings/getUnits/getLeases qui appellent des endpoints inexistants.
**Fix:** Reconstruire getFullSnapshot() à partir de vacant-units uniquement.

### BUG 4 — plexflow-ingestion.service.js
Utilise compareWithLocal() qui dépend de getFullSnapshot() → probablement cassé aussi.
**Fix:** Corriger après avoir fixé getFullSnapshot().

### BUG 5 — Frontend plexflow_service.dart
Le client Dart appelle /api/plexflow/buildings, /api/plexflow/units, etc. — ces endpoints backend sont cassés (BUG 2).
**Fix:** Vérifier et corriger les appels Dart après avoir fixé le backend.

### BUG 6 — plexflow_gap_screen.dart
Affiche des montants probablement en cents (84500 au lieu de 845.00$).
**Fix:** Vérifier l'affichage des montants après correction backend.

## INSTRUCTIONS
1. Lis chaque fichier AVANT de modifier
2. Commence par le backend (plexflow.service.js)
3. Corrige TOUS les appels d'API pour utiliser /property/vacant-units
4. Corrige TOUS les montants pour diviser par 100
5. Vérifie que le frontend Dart est cohérent avec le backend corrigé
6. NE MODIFIE PAS les autres fichiers
7. Vérifie avec flutter analyze après modifications Dart