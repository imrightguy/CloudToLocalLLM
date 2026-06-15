const plexflowWebhookService = require('../services/plexflow-webhook.service');
const { safeSecretEqual } = require('../utils/webhookAuth');
const { child } = require('../utils/logger');

const log = child({ controller: 'plexflow-webhook' });

/**
 * Validate the shared-secret header PlexFlow sends with each webhook.
 * Mirrors the outbound convention (X-Plexflow-Key). Fails closed: when no
 * secret is configured the webhook is rejected rather than accepted blindly,
 * and the comparison is constant-time to avoid timing side-channels.
 * @returns {boolean} true when the request is authorized
 */
function isAuthorized(req) {
  const secret = process.env.PLEXFLOW_WEBHOOK_SECRET || process.env.PLEXFLOW_API_KEY;
  if (!secret) {
    log.error('No PLEXFLOW_WEBHOOK_SECRET configured — rejecting webhook');
    return false;
  }
  const provided = req.get('X-Plexflow-Key') || req.get('x-plexflow-key');
  return safeSecretEqual(provided, secret);
}

// POST /api/webhooks/plexflow (PUBLIC — no JWT)
exports.handleWebhook = async (req, res) => {
  const payload = req.body || {};

  // Always log the raw payload first so nothing is lost if handling fails.
  log.info('PlexFlow webhook received', {
    event: payload.event || payload.eventType || payload.type || null,
  });

  if (!isAuthorized(req)) {
    log.warn('PlexFlow webhook rejected — invalid signature');
    return res.status(401).json({
      success: false,
      error: { message: 'Signature PlexFlow invalide', code: 'PLEXFLOW_WEBHOOK_UNAUTHORIZED' },
    });
  }

  try {
    const result = await plexflowWebhookService.processWebhook(payload);
    return res.status(200).json({ success: true, data: result });
  } catch (error) {
    // Acknowledge receipt with 200 to avoid retry storms; the error is logged.
    log.error('PlexFlow webhook processing failed', { error: error.message });
    return res.status(200).json({
      success: false,
      error: { message: 'Échec du traitement du webhook', code: 'PLEXFLOW_WEBHOOK_FAILED' },
    });
  }
};
