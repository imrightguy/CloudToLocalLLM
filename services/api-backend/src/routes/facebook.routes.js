/**
 * Facebook Webhook Routes
 *
 * No authentication — Facebook sends events here directly.
 * Verification and incoming webhook events for Messenger.
 */

const express = require('express');
const router = express.Router();
const webhookController = require('../controllers/facebook-webhook.controller');

// Verification handshake (GET)
router.get('/', webhookController.verify);

// Incoming webhook events — messages, postbacks, opt-ins (POST)
router.post('/', webhookController.handleWebhook);

module.exports = router;
