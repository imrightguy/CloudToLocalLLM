const logger = require('../utils/logger');
const { parseIncomingWhatsApp, sendWhatsAppMessage, logWhatsAppCommunication, t, detectLanguage, i18n } = require('../services/whatsapp.service');
const { findLeadByPhone, logCrossChannelMessage, CHANNEL_TYPES } = require('../services/conversation-router.service');
const { handleIncomingMessage } = require('../services/twilio.service');
const { refreshCommunicationThread } = require('../services/communication-thread.service');

const WHATSAPP_STATES = {
  NEW: 'NEW',
  ASKED_REASON: 'ASKED_REASON',
  ASKED_BUDGET: 'ASKED_BUDGET',
  ASKED_BUILDING: 'ASKED_BUILDING',
  SUGGEST_VISIT: 'SUGGEST_VISIT',
  DONE: 'DONE',
};

const whatsappConversations = new Map();

function getConversation(phoneNumber) {
  if (!whatsappConversations.has(phoneNumber)) {
    whatsappConversations.set(phoneNumber, {
      state: WHATSAPP_STATES.NEW,
      language: 'fr',
      leadId: null,
      lastActivityAt: new Date(),
      data: {},
    });
  }
  return whatsappConversations.get(phoneNumber);
}

async function handleIncomingWhatsApp(req, res) {
  try {
    const { From, Body, MessageSid, ProfileName, NumMedia } = req.body;
    const normalizedBody = typeof Body === 'string' ? Body : '';

    if (!From) {
      logger.warn('Incoming WhatsApp webhook missing From');
      return res.status(400).send('Missing required fields');
    }

    const cleanPhone = From.replace(/^whatsapp:/, '');

    logger.info(`Incoming WhatsApp from ${cleanPhone}: "${normalizedBody}" (SID: ${MessageSid}, profile=${ProfileName})`);

    const parsed = parseIncomingWhatsApp(normalizedBody);

    let lead = await findLeadByPhone(cleanPhone);

    if (parsed.action === 'stop') {
      logger.info(`WhatsApp opt-out request from ${cleanPhone}`);
      const conv = getConversation(cleanPhone);
      await sendWhatsAppMessage(cleanPhone, t('optOut', conv.language), { leadId: lead?.id });
      return res.status(200).type('text/xml').send('<Response></Response>');
    }

    const conv = getConversation(cleanPhone);
    if (normalizedBody && conv.state === WHATSAPP_STATES.NEW) {
      conv.language = detectLanguage(normalizedBody);
    }
    conv.lastActivityAt = new Date();

    await logWhatsAppCommunication({
      leadId: lead?.id || null,
      direction: 'inbound',
      content: normalizedBody,
      status: 'received',
      metadata: {
        twilioMessageSid: MessageSid,
        profileName: ProfileName || null,
        numMedia: Number.parseInt(NumMedia, 10) || 0,
        channel: CHANNEL_TYPES.WHATSAPP,
        from: From,
      },
    });

    if (lead?.id) {
      await logCrossChannelMessage({
        leadId: lead.id,
        channel: CHANNEL_TYPES.WHATSAPP,
        direction: 'inbound',
        content: normalizedBody,
        status: 'received',
        metadata: {
          twilioMessageSid: MessageSid,
          profileName: ProfileName || null,
        },
      });
    }

    const reply = await processConversation(conv, normalizedBody, parsed, lead);

    if (reply && lead) {
      conv.leadId = lead.id;
    }

    if (reply) {
      await sendWhatsAppMessage(cleanPhone, reply, {
        leadId: lead?.id || conv.leadId,
        metadata: { conversationState: conv.state },
      });
    }

    if (lead?.id) {
      await refreshCommunicationThread(lead.id, { includeMessages: false }).catch(() => {});
    }

    return res.status(200).type('text/xml').send('<Response></Response>');
  } catch (error) {
    logger.error('handleIncomingWhatsApp error:', error.message);
    return res.status(200).type('text/xml').send('<Response></Response>');
  }
}

async function processConversation(conv, body, parsed, lead) {
  const lang = conv.language || 'fr';

  switch (conv.state) {
    case WHATSAPP_STATES.NEW: {
      conv.state = WHATSAPP_STATES.ASKED_REASON;
      return `${t('welcome', lang)}\n\n${t('askReason', lang)}`;
    }

    case WHATSAPP_STATES.ASKED_REASON: {
      conv.data.reason = body;
      conv.state = WHATSAPP_STATES.ASKED_BUDGET;
      return t('askBudget', lang);
    }

    case WHATSAPP_STATES.ASKED_BUDGET: {
      conv.data.budget = body;
      conv.state = WHATSAPP_STATES.ASKED_BUILDING;
      return t('askBuilding', lang);
    }

    case WHATSAPP_STATES.ASKED_BUILDING: {
      conv.data.buildingInterest = body;
      conv.state = WHATSAPP_STATES.SUGGEST_VISIT;
      return t('suggestVisit', lang);
    }

    case WHATSAPP_STATES.SUGGEST_VISIT: {
      if (parsed.action === 'yes') {
        conv.state = WHATSAPP_STATES.DONE;
        return t('visitBooked', lang);
      }
      if (parsed.action === 'no') {
        conv.state = WHATSAPP_STATES.DONE;
        return t('thankYou', lang);
      }
      return t('suggestVisit', lang);
    }

    case WHATSAPP_STATES.DONE: {
      return t('fallback', lang);
    }

    default: {
      return t('fallback', lang);
    }
  }
}

module.exports = {
  handleIncomingWhatsApp,
  processConversation,
  WHATSAPP_STATES,
  getConversation,
};
