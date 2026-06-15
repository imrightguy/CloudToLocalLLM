# TASK — PlexFlow Webhooks → SMS/Emails Automatiques Départ/Arrivée

Tu es un développeur senior full-stack (Node.js/Express/Drizzle/PostgreSQL + Flutter). Implémente le système de webhooks PlexFlow pour automatiser les communications départ/arrivée des locataires.

## Vision
Quand PlexFlow détecte un événement (locataire qui part, locataire qui arrive, unité vacante, bail renouvelé), ImmoGestion reçoit le webhook en temps réel et envoie automatiquement un SMS/email au locataire concerné. Des photos de départ/arrivée sont stockées. Messages customisables. Zéro intervention manuelle.

## Architecture

```
PlexFlow → POST webhook → ImmoGestion /api/webhooks/plexflow
  → plexflow-webhook.service.js (dispatcher)
    → Événement "Locataire désactivé" → SMS départ + demande photos
    → Événement "Locataire activé" → SMS bienvenue + demande photos
    → Événement "Unité devenue vacante" → Email à Simon
    → Événement "Unité occupée" → Email à Simon
    → Événement "Bail créé/renouvelé" → SMS confirmation
  → Stocke le message dans sms_messages + photos dans departure_photos
```

## Fichiers à créer

### 1. `services/api-backend/src/services/plexflow-webhook.service.js`
- Reçoit le payload du webhook PlexFlow
- Détecte le type d'événement (tenant_activated, tenant_deactivated, unit_vacant, unit_occupied, lease_created, lease_renewed)
- Extrait les infes : nom locataire, téléphone, unité, bâtiment, dates
- Appelle `sms.service.js` pour envoyer le SMS
- Appelle `notification.service.js` pour notifier Simon
- Stocke les photos dans la table `departure_photos`

### 2. `services/api-backend/src/controllers/plexflow-webhook.controller.js`
- Endpoint POST `/api/webhooks/plexflow`
- Valide la signature PlexFlow (si dispo)
- Log le payload brut
- Appelle le dispatcher

### 3. Route dans `plexflow.routes.js` (ou nouveau fichier)
- `POST /webhooks/plexflow` (PUBLIC — pas de JWT, PlexFlow ne peut pas s'authentifier)

### 4. Table `departure_photos` dans le schema Drizzle
- `id`, `buildingId`, `unitId`, `tenantName`, `eventType` (departure/arrival), `photoUrl`, `notes`, `createdAt`

### 5. `services/api-backend/src/services/departure-photos.service.js`
- CRUD basique pour la table departure_photos

### 6. `lib/screens/departure_photos_screen.dart` (Flutter)
- Écran qui liste les photos de départ/arrivée par bâtiment
- Mini-galerie avec date, locataire, type d'événement

### 7. Settings — messages custom
- Ajouter dans `settings_screen.dart` une section "Messages automatiques"
- Permettre de personnaliser les templates SMS pour chaque type d'événement
- Stocker dans `app_settings` ou une table `message_templates`

## Messages par défaut (français québécois)

| Événement | SMS au locataire |
|---|---|
| **Départ** | "Bonjour {tenantName}, votre départ du {unitLabel} est prévu le {date}. Prenez des photos de l'état du logement et envoyez-les ici. Merci! — Simon Gravel" |
| **Arrivée** | "Bienvenue {tenantName} au {unitLabel}! Votre bail débute le {date}. Prenez des photos de votre arrivée pour l'état des lieux. Des questions? Contactez-moi. — Simon Gravel" |
| **Renouvellement** | "Bonjour {tenantName}, votre bail au {unitLabel} a été renouvelé jusqu'au {date}. Merci de votre confiance! — Simon Gravel" |

| Événement | Email à Simon |
|---|---|
| **Unité vacante** | "{unitLabel} ({buildingName}) sera vacant dès le {date}. Locataire sortant: {tenantName}. Action: mettre en annonce." |
| **Unité occupée** | "{unitLabel} ({buildingName}) est maintenant occupé par {tenantName}. Bail début: {date}." |

## Règles
- Lis chaque fichier existant avant de modifier
- Les webhooks PlexFlow arrivent sans JWT → route publique avec signature validation si possible
- Si le téléphone du locataire n'est pas dans le payload PlexFlow, cherche dans la DB locale (units.tenantPhone)
- Si toujours pas de téléphone, envoie un email à Simon: "Téléphone manquant pour {tenantName} — webhook reçu mais SMS non envoyé"
- Les photos sont stockées comme URLs (le locataire reçoit un lien pour uploader)
- Utilise `patch` (mode replace) pour les modifications
- Vérifie avec `flutter analyze` après changements Dart
