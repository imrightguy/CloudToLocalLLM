/**
 * @swagger
 * tags:
 *   - name: Facebook
 *     description: Facebook Messenger webhook endpoints (no auth)
 */

/**
 * @swagger
 * /api/webhooks/facebook:
 *   get:
 *     tags: [Facebook]
 *     summary: Facebook webhook verification
 *     description: Handshake endpoint called by Facebook during webhook setup. Returns the hub.challenge value to verify ownership.
 *     parameters:
 *       - in: query
 *         name: hub.mode
 *         required: true
 *         schema:
 *           type: string
 *         description: Must be "subscribe"
 *       - in: query
 *         name: hub.verify_token
 *         required: true
 *         schema:
 *           type: string
 *         description: Verification token configured in Facebook app
 *       - in: query
 *         name: hub.challenge
 *         required: true
 *         schema:
 *           type: string
 *         description: Challenge string to echo back
 *     responses:
 *       200:
 *         description: Verification successful
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 *       403:
 *         description: Invalid verify token
 */

/**
 * @swagger
 * /api/webhooks/facebook:
 *   post:
 *     tags: [Facebook]
 *     summary: Facebook webhook events
 *     description: Receives incoming Facebook Messenger events (messages, postbacks, opt-ins).
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               object:
 *                 type: string
 *                 example: "page"
 *               entry:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     messaging:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           sender:
 *                             type: object
 *                             properties:
 *                               id: { type: string }
 *                           recipient:
 *                             type: object
 *                             properties:
 *                               id: { type: string }
 *                           message:
 *                             type: object
 *                             properties:
 *                               mid: { type: string }
 *                               text: { type: string }
 *     responses:
 *       200:
 *         description: Event processed
 */

const express = require('express');

const router = express.Router();
const webhookController = require('../controllers/facebook-webhook.controller');

router.get('/', webhookController.verify);
router.post('/', webhookController.handleWebhook);

module.exports = router;
