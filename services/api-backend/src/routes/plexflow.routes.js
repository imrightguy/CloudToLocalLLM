const express = require('express');

const router = express.Router();
const plexflowController = require('../controllers/plexflow.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { plexflowSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/plexflow/buildings:
 *   get:
 *     tags: [PlexFlow]
 *     summary: List PlexFlow buildings (read-only)
 *     description: Returns buildings synced from PlexFlow. Cached for one hour.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: PlexFlow buildings
 */
router.get('/buildings', authenticateToken, asyncHandler(plexflowController.getBuildings));

/**
 * @swagger
 * /api/plexflow/buildings/{id}/units:
 *   get:
 *     tags: [PlexFlow]
 *     summary: List units of a PlexFlow building
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: PlexFlow units
 */
router.get('/buildings/:id/units', authenticateToken, validate(plexflowSchemas.idParam), asyncHandler(plexflowController.getUnits));

/**
 * @swagger
 * /api/plexflow/units/{id}/leases:
 *   get:
 *     tags: [PlexFlow]
 *     summary: List leases of a PlexFlow unit
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: PlexFlow leases
 */
router.get('/units/:id/leases', authenticateToken, validate(plexflowSchemas.idParam), asyncHandler(plexflowController.getLeases));

/**
 * @swagger
 * /api/plexflow/units/{id}/tenants:
 *   get:
 *     tags: [PlexFlow]
 *     summary: List tenants of a PlexFlow unit
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: PlexFlow tenants
 */
router.get('/units/:id/tenants', authenticateToken, validate(plexflowSchemas.idParam), asyncHandler(plexflowController.getTenants));

/**
 * @swagger
 * /api/plexflow/buildings/{id}/gap-analysis:
 *   get:
 *     tags: [PlexFlow]
 *     summary: Analyse des écarts entre PlexFlow et la DB locale
 *     description: Compare le snapshot PlexFlow d'un bâtiment avec les données locales.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Rapport d'écarts (unités/baux/locataires manquants)
 */
router.get('/buildings/:id/gap-analysis', authenticateToken, validate(plexflowSchemas.idParam), asyncHandler(plexflowController.getGapAnalysis));

/**
 * @swagger
 * /api/plexflow/buildings/{id}/ingest:
 *   post:
 *     tags: [PlexFlow]
 *     summary: Ingérer les données PlexFlow manquantes dans la DB locale
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Rapport d'ingestion (créations/mises à jour/erreurs)
 */
router.post('/buildings/:id/ingest', authenticateToken, validate(plexflowSchemas.idParam), asyncHandler(plexflowController.ingestMissing));

/**
 * @swagger
 * /api/plexflow/sync:
 *   post:
 *     tags: [PlexFlow]
 *     summary: Trigger a manual PlexFlow synchronization
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Sync result
 */
router.post('/sync', authenticateToken, asyncHandler(plexflowController.sync));

module.exports = router;
