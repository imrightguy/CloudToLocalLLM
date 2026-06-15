// ─── PlexFlow Webhook Routes ───
// PUBLIC (no JWT) — PlexFlow cannot authenticate with a user token. Requests are
// authorized via the X-Plexflow-Key shared-secret header (validated in the
// controller). Mounted at /api/webhooks/plexflow.

const express = require('express');

const router = express.Router();
const plexflowWebhookController = require('../controllers/plexflow-webhook.controller');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { plexflowWebhookSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/webhooks/plexflow:
 *   post:
 *     tags: [PlexFlow]
 *     summary: Webhook PlexFlow (départ/arrivée locataire, unité vacante/occupée, bail)
 *     description: >
 *       Reçoit les événements PlexFlow en temps réel et déclenche les SMS/emails
 *       automatiques. Route publique authentifiée par l'en-tête X-Plexflow-Key.
 *     responses:
 *       200:
 *         description: Webhook reçu et traité
 *       401:
 *         description: Signature PlexFlow invalide
 */
router.post(
  '/',
  validate(plexflowWebhookSchemas.webhook),
  asyncHandler(plexflowWebhookController.handleWebhook),
);

module.exports = router;
