// ─── Voice AI Controller ───
// Endpoints pour les webhooks Twilio Voice.

const voiceAiService = require('../services/voice-ai.service');
const { validateTwilioWebhook } = require('../services/twilio.service');
const logger = require('../utils/logger');

/**
 * POST /webhooks/twilio/voice
 * Reçoit un appel entrant Twilio → pipeline Voice AI complet.
 */
exports.handleIncomingCall = async (req, res) => {
  try {
    const { CallSid, From, To, CallStatus } = req.body;

    if (!CallSid || !From) {
      logger.warn('[voice-ai.controller] Webhook incomplet');
      return res.status(400).type('text/xml').send('<Response><Say language="fr-CA">Données manquantes.</Say></Response>');
    }

    // Ignorer les appels déjà terminés (status callbacks)
    if (CallStatus && CallStatus !== 'ringing' && CallStatus !== 'in-progress') {
      logger.info(`[voice-ai.controller] Status callback ignoré: ${CallSid} ${CallStatus}`);
      return res.status(200).type('text/xml').send('<Response></Response>');
    }

    logger.info(`[voice-ai.controller] Appel entrant: ${CallSid} de ${From}`);

    // Accueillir l'appelant et enregistrer sa demande. Le pipeline
    // STT→LLM→ticket est déclenché une seule fois, depuis handleRecording,
    // une fois l'enregistrement disponible (évite les tickets en double).
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="fr-CA" voice="alice">Bienvenue chez ImmoGestion. Veuillez décrire votre problème de maintenance après le bip sonore.</Say>
  <Record maxLength="120" playBeep="true" action="/webhooks/twilio/voice/recording" method="POST" />
</Response>`;

    return res.status(200).type('text/xml').send(twiml);
  } catch (error) {
    logger.error('[voice-ai.controller] Erreur webhook:', error.message);
    return res.status(200).type('text/xml').send('<Response><Say language="fr-CA">Une erreur est survenue. Veuillez rappeler.</Say></Response>');
  }
};

/**
 * POST /webhooks/twilio/voice/recording
 * Reçoit l'enregistrement Twilio → déclenche le pipeline complet.
 */
exports.handleRecording = async (req, res) => {
  try {
    const { CallSid, From, To, RecordingUrl, RecordingDuration } = req.body;

    if (!CallSid || !RecordingUrl) {
      logger.warn('[voice-ai.controller] Recording webhook incomplet');
      return res.status(400).type('text/xml').send('<Response></Response>');
    }

    logger.info(`[voice-ai.controller] Enregistrement reçu: ${CallSid}, durée=${RecordingDuration}s`);

    // En production: télécharger l'audio depuis RecordingUrl, passer à Deepgram STT
    // Pour l'instant: le pipeline utilise le mode dégradé (transcript simulé)
    const result = await voiceAiService.handleIncomingCall(CallSid, From, To);

    const urgencyLabels = {
      basse: 'basse',
      moyenne: 'moyenne',
      haute: 'haute',
      urgence: 'urgence',
    };

    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="fr-CA" voice="alice">Votre demande a été enregistrée. Niveau d'urgence: ${urgencyLabels[result.classification.urgency] || 'moyenne'}. Un technicien vous contactera.</Say>
  <Hangup />
</Response>`;

    return res.status(200).type('text/xml').send(twiml);
  } catch (error) {
    logger.error('[voice-ai.controller] Erreur recording:', error.message);
    return res.status(200).type('text/xml').send('<Response><Say language="fr-CA">Votre demande a été enregistrée. Merci.</Say><Hangup /></Response>');
  }
};

/**
 * POST /webhooks/twilio/voice/status
 * Call status updates (completed, failed, etc.)
 */
exports.handleStatus = async (req, res) => {
  try {
    const { CallSid, CallStatus, CallDuration } = req.body;
    logger.info(`[voice-ai.controller] Status appel: ${CallSid} → ${CallStatus} (${CallDuration}s)`);
    return res.status(200).send('OK');
  } catch (error) {
    logger.error('[voice-ai.controller] Erreur status:', error.message);
    return res.status(200).send('OK');
  }
};
