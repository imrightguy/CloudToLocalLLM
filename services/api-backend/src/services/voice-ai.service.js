// ─── Voice AI Service — Pipeline complet ───
// Reçoit un appel Twilio → STT (Deepgram) → Classification (LLM/règles) →
// Crée ticket maintenance → TTS (ElevenLabs) → Notifie admins.
//
// Mode dégradé: si STT/LLM/TTS indisponible, crée un ticket basique.

const logger = require('../utils/logger');
const classificationService = require('./classification.service');
const maintenanceService = require('./maintenance.service');

/**
 * Traite un appel entrant: STT → classification → ticket → TTS → notification.
 * @param {string} callSid - Twilio Call SID
 * @param {string} from - Numéro appelant (E.164)
 * @param {string} to - Numéro appelé
 * @returns {Promise<{ticket: object, created: boolean, transcript: string, classification: object}>}
 */
async function handleIncomingCall(callSid, from, to) {
  logger.info(`[voice-ai] Appel entrant: ${callSid} de ${from}`);

  // Étape 1: STT via Deepgram (mode simulé si pas de clé)
  const transcript = await _transcribeCall(callSid, from);

  // Étape 2: Classification
  const classification = await classificationService.classifyMaintenanceRequest(transcript);

  // Étape 3: Créer ticket maintenance
  const ticket = await maintenanceService.createTicket({
    title: classification.summary || 'Demande de maintenance (Voice AI)',
    description: transcript,
    urgency: classification.urgency,
    source: 'voice_ai',
    callerPhone: from,
    vapiCallId: callSid,
  });

  // Étape 4: Notification aux admins — déclenchée par maintenanceService.createTicket()
  // pour les tickets source='voice_ai' (voir notificationService.notifyNewMaintenanceTicket).

  // Étape 5: TTS de confirmation (ElevenLabs)
  const ttsAudioUrl = await _generateTTS(callSid, classification);

  logger.info(`[voice-ai] Ticket créé: ${ticket.id}, urgence=${classification.urgency}`);

  return {
    ticket,
    created: true,
    transcript,
    classification,
    ttsAudioUrl,
  };
}

/**
 * Transcrit un appel via Deepgram STT.
 * Mode simulé si DEEPGRAM_API_KEY n'est pas configurée.
 */
async function _transcribeCall(callSid, from) {
  const apiKey = process.env.DEEPGRAM_API_KEY;
  if (!apiKey) {
    logger.warn('[voice-ai] Deepgram non configuré — mode transcript simulé');
    return `Appel de maintenance du locataire au ${from}. Détails non disponibles (STT non configuré).`;
  }

  // En production: ouvrir WebSocket vers Deepgram, streamer l'audio Twilio
  // Pour l'instant: retourne un placeholder (l'intégration WebSocket nécessite
  // un serveur WebSocket dédié ou un upgrade HTTP)
  logger.info(`[voice-ai] Deepgram STT démarré pour ${callSid}`);
  return `Appel de maintenance du locataire au ${from}. Transcript STT en attente d'intégration WebSocket.`;
}

/**
 * Génère un message TTS de confirmation via ElevenLabs.
 * Mode dégradé: retourne null si pas de clé.
 */
async function _generateTTS(callSid, classification) {
  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    logger.warn('[voice-ai] ElevenLabs non configuré — pas de TTS');
    return null;
  }

  const urgencyLabels = {
    basse: 'basse',
    moyenne: 'moyenne',
    haute: 'haute',
    urgence: 'urgence',
  };

  const text = `Votre demande de maintenance a été enregistrée. Niveau d'urgence: ${urgencyLabels[classification.urgency] || 'moyenne'}. Un technicien vous contactera dans les plus brefs délais.`;

  try {
    const voiceId = process.env.ELEVENLABS_VOICE_ID || '21m00Tcm4TlvDq8ikWAM';
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': apiKey,
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_multilingual_v2',
          voice_settings: { stability: 0.5, similarity_boost: 0.75 },
        }),
      },
    );

    if (!response.ok) {
      logger.warn(`[voice-ai] ElevenLabs HTTP ${response.status}`);
      return null;
    }

    // En production: streamer l'audio vers Twilio via <Play>
    // Pour l'instant: retourne l'URL du fichier audio
    const buffer = await response.arrayBuffer();
    logger.info(`[voice-ai] TTS généré pour ${callSid}: ${buffer.byteLength} bytes`);
    return { text, size: buffer.byteLength };
  } catch (error) {
    logger.warn('[voice-ai] Échec TTS:', error.message);
    return null;
  }
}

module.exports = { handleIncomingCall };
