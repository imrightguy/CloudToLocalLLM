const express = require('express');
const router = express.Router();
const { handleIncomingWhatsApp } = require('../controllers/twilio-whatsapp.controller');
const { asyncHandler } = require('../utils/apiResponse');

/**
 * @swagger
 * /api/webhooks/twilio/whatsapp:
 *   post:
 *     tags: [WhatsApp Webhooks]
 *     summary: Incoming WhatsApp message webhook
 *     description: >
 *       Webhook called by Twilio when an incoming WhatsApp message is received.
 *       No authentication required (Twilio validates via webhook signature).
 *     requestBody:
 *       required: true
 *       content:
 *         application/x-www-form-urlencoded:
 *           schema:
 *             type: object
 *             required:
 *               - From
 *             properties:
 *               MessageSid:
 *                 type: string
 *                 description: Twilio message SID
 *               From:
 *                 type: string
 *                 description: Sender WhatsApp number (prefixed with "whatsapp:")
 *               To:
 *                 type: string
 *                 description: Receiver WhatsApp number
 *               Body:
 *                 type: string
 *                 description: Message body text
 *               ProfileName:
 *                 type: string
 *                 description: WhatsApp profile name of sender
 *               NumMedia:
 *                 type: string
 *                 description: Number of media attachments
 *     responses:
 *       200:
 *         description: TwiML response
 *         content:
 *           text/xml:
 *             schema:
 *               type: string
 *       400:
 *         description: Missing required fields
 */
router.post('/', asyncHandler(handleIncomingWhatsApp));

module.exports = router;
