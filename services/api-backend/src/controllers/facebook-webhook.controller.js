/**
 * Facebook Webhook Controller
 *
 * Handles GET (verification) and POST (incoming events) for the
 * Facebook webhook endpoint.
 * Supports both Messenger events and Lead Ads webhooks.
 */

const { FB_VERIFY_TOKEN } = process.env;

const botService = require('../services/messenger-bot.service');
const facebookService = require('../services/facebook.service');
const logger = require('../utils/logger');

if (!FB_VERIFY_TOKEN) {
  logger.warn('[FB Webhook] FB_VERIFY_TOKEN is not set. Webhook verification will fail.');
}

// ─── GET /webhooks/facebook — Verification Handshake ───
exports.verify = (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === FB_VERIFY_TOKEN) {
    logger.info('[FB Webhook] Verification successful');
    return res.status(200).send(challenge);
  }

  logger.error('[FB Webhook] Verification failed — invalid token or mode');
  return res.status(403).send('Forbidden');
};

// ─── POST /webhooks/facebook — Incoming Events ───
exports.handleWebhook = async (req, res) => {
  // Always respond 200 quickly to prevent Facebook retries
  res.status(200).send('EVENT_RECEIVED');

  const { body } = req;

  if (body.object !== 'page') {
    return;
  }

  // Process each entry (FB may batch events)
  for (const entry of body.entry || []) {
    // Handle Messenger events
    for (const messagingEvent of entry.messaging || []) {
      try {
        const senderId = messagingEvent.sender?.id;
        if (!senderId) continue;

        // Handle text messages
        if (messagingEvent.message) {
          // Ignore echo messages (our own outgoing messages)
          if (messagingEvent.message.is_echo) continue;

          const messageText = messagingEvent.message.text || '';

          // Check for quick reply payload
          if (messagingEvent.message.quick_reply?.payload) {
            await botService.handlePostback(senderId, messagingEvent.message.quick_reply.payload);
          } else if (messageText.trim()) {
            await botService.handleIncomingMessage(senderId, messageText);
          }
        }

        // Handle postback events (generic template button taps)
        if (messagingEvent.postback) {
          const { payload } = messagingEvent.postback;
          if (payload) {
            await botService.handlePostback(senderId, payload);
          }
        }

        // Handle opt-in events
        if (messagingEvent.optin) {
          const ref = messagingEvent.optin.ref || '';
          await botService.handleOptIn(senderId, ref);
        }
      } catch (err) {
        logger.error('[FB Webhook] Error processing messaging event:', err);
      }
    }

    // Handle Lead Ads changes
    for (const change of entry.changes || []) {
      try {
        if (change.field === 'leadgen_id') {
          await facebookService.processLeadAdWebhook(change.value);
        }
      } catch (err) {
        logger.error('[FB Webhook] Error processing lead ad event:', err);
      }
    }
  }
};
