// ─── Voice Routes ───
// Webhooks Twilio pour le Voice AI agent.

const express = require('express');
const router = express.Router();
const voiceAiController = require('../controllers/voice-ai.controller');
const { validateTwilioWebhook } = require('../services/twilio.service');

// POST /webhooks/twilio/voice — appel entrant
router.post(
  '/',
  express.urlencoded({ extended: false }),
  validateTwilioWebhook,
  voiceAiController.handleIncomingCall,
);

// POST /webhooks/twilio/voice/recording — enregistrement terminé
router.post(
  '/recording',
  express.urlencoded({ extended: false }),
  validateTwilioWebhook,
  voiceAiController.handleRecording,
);

// POST /webhooks/twilio/voice/status — call status updates
router.post(
  '/status',
  express.urlencoded({ extended: false }),
  voiceAiController.handleStatus,
);

module.exports = router;
