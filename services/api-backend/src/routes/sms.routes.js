const express = require('express');

const router = express.Router();
const smsWebhookController = require('../controllers/sms-webhook.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

// ─── Public webhooks (Twilio calls these — no auth) ───
router.post('/sms/incoming', asyncHandler(smsWebhookController.handleIncoming));
router.post('/sms/status', asyncHandler(smsWebhookController.handleStatus));

// ─── Internal endpoint (requires auth) ───
router.post('/sms/schedule', authenticateToken, asyncHandler(smsWebhookController.handleSchedule));

module.exports = router;
