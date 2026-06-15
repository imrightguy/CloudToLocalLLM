# TASK — Système de Photos de Bâtiments / Logements

Tu es un développeur senior full-stack (Node.js/Express/Drizzle/PostgreSQL + Flutter). Implémente un système complet de gestion de photos pour les bâtiments et logements dans ImmoGestion.

## Vision
Simon visite un nouveau bâtiment → il upload les photos directement dans ImmoGestion → les photos sont classées par bâtiment/logement/catégorie → quand un logement se vide, les photos récentes sont déjà là pour la relocation. Zéro aller-retour pour reprendre des photos.

## Use cases
1. **Acquisition** : Simon visite un building potentiel, prend 30 photos, les upload dans ImmoGestion → visibles dans la fiche du bâtiment
2. **Rénovation** : Photos "avant" stockées, photos "après" ajoutées → suivi des travaux
3. **Relocation** : Un logement se vide → les photos récentes sont déjà dans le système → utilisables pour l'annonce
4. **État des lieux** : Photos départ/arrivée des locataires (complément aux webhooks PlexFlow)

## Fichiers à créer

### Backend

#### 1. Table `property_photos` dans `services/api-backend/src/database/schema.js`
Ajouter après les tables existantes :
```javascript
propertyPhotosTable = pgTable('property_photos', {
  id: uuid('id').defaultRandom().primaryKey(),
  buildingId: uuid('building_id').references(() => buildingsTable.id).notNull(),
  unitId: uuid('unit_id').references(() => unitsTable.id),  // nullable — photo du bâtiment entier
  category: varchar('category', { length: 50 }).notNull().default('general'),
    // 'exterior', 'interior', 'renovation', 'departure', 'arrival', 'general'
  photoUrl: varchar('photo_url', { length: 1000 }).notNull(),
  thumbnailUrl: varchar('thumbnail_url', { length: 1000 }),
  caption: varchar('caption', { length: 500 }),
  tags: jsonb('tags').default([]),  // ['cuisine', 'salle de bain', 'plancher']
  takenAt: timestamp('taken_at'),  // date de la photo (pas de l'upload)
  uploadedBy: uuid('uploaded_by').references(() => usersTable.id),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
})
```

#### 2. `services/api-backend/src/services/property-photos.service.js`
- `uploadPhoto(buildingId, file, metadata)` — reçoit un fichier, le stocke dans `/app/uploads/photos/`, crée l'entrée DB
- `getPhotosByBuilding(buildingId, { category, unitId, limit, offset })` — liste filtrée
- `getPhotosByUnit(unitId)` — photos d'un logement spécifique
- `deletePhoto(id)` — soft delete (isActive = false)
- `updatePhoto(id, { caption, tags, category })` — mise à jour metadata

#### 3. `services/api-backend/src/controllers/property-photos.controller.js`
- `POST /property-photos/upload` — multipart form (buildingId, unitId?, category, caption, tags, takenAt)
- `GET /property-photos/building/:buildingId` — query params: category, unitId, page, limit
- `GET /property-photos/unit/:unitId`
- `DELETE /property-photos/:id`
- `PATCH /property-photos/:id` — update metadata

#### 4. Routes dans `services/api-backend/src/routes/property-photos.routes.js`
- Toutes protégées par `authenticateToken`
- Upload avec multer (limite 10 MB, formats jpg/png/webp)

#### 5. Ajouter la route dans `routes/index.js`
```javascript
router.use('/property-photos', propertyPhotosRoutes);
```

### Frontend Flutter

#### 6. `lib/services/property_photos_service.dart`
- `uploadPhoto(buildingId, file, metadata)` — multipart upload
- `getPhotosByBuilding(buildingId, filters)`
- `getPhotosByUnit(unitId)`
- `deletePhoto(id)`
- `updatePhoto(id, data)`

#### 7. `lib/screens/property_photos_screen.dart`
Écran principal — galerie de photos par bâtiment :
- **Header** : Nom du bâtiment, sélecteur de catégorie (chips: Toutes, Extérieur, Intérieur, Rénovation, Départ, Arrivée)
- **Grille de photos** : thumbnails en masonry grid (2-3 colonnes selon largeur)
- **Tap sur une photo** → plein écran avec caption, tags, date, bouton delete (si admin)
- **FAB "Ajouter photos"** → ouvre le picker de fichiers (multi-select) → upload avec catégorie par défaut
- **Empty state** : "Aucune photo — ajoutez des photos pour documenter ce bâtiment"
- **Loading** : skeleton grid

#### 8. Intégration dans `building_detail_screen.dart`
Ajouter une section "Photos" avec un aperçu des 4-6 dernières photos + bouton "Voir toutes les photos" → navigation vers `PropertyPhotosScreen`

#### 9. Intégration dans `unit_detail_screen.dart`
Ajouter une section "Photos du logement" avec aperçu + lien vers photos filtrées par unité

## Règles
- Lis chaque fichier existant avant de modifier
- Utilise `patch` (mode replace) pour les modifications
- Vérifie avec `flutter analyze` après changements Dart
- Les photos sont stockées sur le disque du serveur (`/app/uploads/photos/`) et servies via nginx ou un endpoint static
- Thumbnails générés automatiquement (sharp ou canvas côté serveur, ou juste redimensionnement CSS côté client)
- Supporte jpg, png, webp — max 10 MB par fichier
- Les URLs des photos doivent être accessibles publiquement pour les annonces
