const express = require('express');

const router = express.Router();
const smsWebhookController = require('../controllers/sms-webhook.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

/**
 * @swagger
 * /api/webhooks/sms/incoming:
 *   post:
 *     tags: [SMS Webhooks]
 *     summary: Incoming SMS webhook
 *     description: Webhook called by Twilio when an incoming SMS is received. No authentication required.
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             properties:
 *               MessageSid:
 *                 type: string
 *                 description: Twilio message SID
 *               From:
 *                 type: string
 *                 description: Sender phone number
 *               To:
 *                 type: string
 *                 description: Receiver phone number
 *               Body:
 *                 type: string
 *                 description: Message body
 *     responses:
 *       200:
 *         description: TwiML response
 *         content:
 *           text/xml:
 *             schema:
 *               type: string
 */
router.post('/sms/incoming', asyncHandler(smsWebhookController.handleIncoming));

/**
 * @swagger
 * /api/webhooks/sms/status:
 *   post:
 *     tags: [SMS Webhooks]
 *     summary: SMS delivery status webhook
 *     description: Webhook called by Twilio when an SMS status changes (sent, delivered, failed). No authentication required.
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             properties:
 *               MessageSid:
 *                 type: string
 *               MessageStatus:
 *                 type: string
 *                 enum: [queued, sent, delivered, undelivered, failed]
 *     responses:
 *       200:
 *         description: Status acknowledged
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 */
router.post('/sms/status', asyncHandler(smsWebhookController.handleStatus));

/**
 * @swagger
 * /api/webhooks/sms/schedule:
 *   post:
 *     tags: [SMS Webhooks]
 *     summary: Schedule an SMS
 *     description: Manually schedule an SMS to be sent. Requires authentication.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - to
 *               - body
 *             properties:
 *               to:
 *                 type: string
 *                 description: Recipient phone number (E.164 format)
 *                 example: "+15145550100"
 *               body:
 *                 type: string
 *                 description: SMS message body
 *               scheduledAt:
 *                 type: string
 *                 format: date-time
 *                 description: When to send the message
 *     responses:
 *       201:
 *         description: SMS scheduled
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       400:
 *         description: Invalid phone number or message
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/sms/schedule', authenticateToken, asyncHandler(smsWebhookController.handleSchedule));

module.exports = router;
