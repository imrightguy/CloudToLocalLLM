const twilio = require('twilio');
const logger = require('../utils/logger');
const {
  normalizeCommunicationAttachments,
  normalizeCommunicationMetadata,
  normalizeCommunicationStatus,
  normalizeCommunicationText,
} = require('../utils/communication');
const { db } = require('../database/connection');
const { communicationLogsTable } = require('../database/schema');
const { sql } = require('drizzle-orm');

let twilioClient = null;
let isInitialized = false;

const WHATSAPP_TYPE = 'whatsapp';
const TWILIO_WHATSAPP_PREFIX = 'whatsapp:';

const initWhatsApp = () => {
  try {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;

    if (!accountSid || !authToken) {
      logger.warn('Twilio credentials not configured (TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN). WhatsApp will be disabled.');
      isInitialized = false;
      return false;
    }

    twilioClient = twilio(accountSid, authToken);
    isInitialized = true;
    logger.info('WhatsApp service initialized (Twilio Conversations)');
    return true;
  } catch (error) {
    logger.error('Failed to initialize WhatsApp service:', error.message);
    isInitialized = false;
    return false;
  }
};

const isReady = () => isInitialized && twilioClient !== null;

const getWhatsAppSender = () => {
  const number = process.env.TWILIO_WHATSAPP_NUMBER || process.env.TWILIO_PHONE_NUMBER || null;
  if (!number) return null;
  return number.startsWith(TWILIO_WHATSAPP_PREFIX) ? number : `${TWILIO_WHATSAPP_PREFIX}${number}`;
};

const formatWhatsAppRecipient = (phoneNumber) => {
  if (!phoneNumber) return null;
  const cleaned = phoneNumber.replace(/[\s\-()]/g, '');
  return cleaned.startsWith(TWILIO_WHATSAPP_PREFIX) ? cleaned : `${TWILIO_WHATSAPP_PREFIX}${cleaned}`;
};

const sendWhatsAppMessage = async (to, body, { mediaUrl = null, leadId = null, employeeId = null, metadata = {} } = {}) => {
  try {
    if (!isReady()) {
      logger.warn('WhatsApp not initialized — skipping sendWhatsAppMessage');
      return { success: false, error: 'WhatsApp not initialized' };
    }

    if (!to || !body) {
      return { success: false, error: 'Phone number and message body are required' };
    }

    const from = getWhatsAppSender();
    if (!from) {
      return { success: false, error: 'TWILIO_WHATSAPP_NUMBER or TWILIO_PHONE_NUMBER not configured' };
    }

    const formattedTo = formatWhatsAppRecipient(to);
    const messageParams = {
      body,
      from,
      to: formattedTo,
    };

    if (mediaUrl) {
      messageParams.mediaUrl = Array.isArray(mediaUrl) ? mediaUrl : [mediaUrl];
    }

    const message = await twilioClient.messages.create(messageParams);

    await logWhatsAppCommunication({
      leadId,
      employeeId,
      direction: 'outbound',
      content: body,
      status: 'sent',
      metadata: {
        ...metadata,
        twilioMessageSid: message.sid,
        twilioStatus: message.status,
        channel: WHATSAPP_TYPE,
        to: formattedTo,
        from,
      },
    });

    return {
      success: true,
      sid: message.sid,
      status: message.status,
    };
  } catch (error) {
    logger.error('sendWhatsAppMessage error:', error.message);
    return { success: false, error: error.message };
  }
};

const sendWhatsAppTemplate = async (to, templateParams = {}, { leadId = null, employeeId = null, metadata = {} } = {}) => {
  try {
    if (!isReady()) {
      return { success: false, error: 'WhatsApp not initialized' };
    }

    if (!to) {
      return { success: false, error: 'Phone number is required' };
    }

    const from = getWhatsAppSender();
    if (!from) {
      return { success: false, error: 'WhatsApp sender number not configured' };
    }

    const formattedTo = formatWhatsAppRecipient(to);
    const { contentSid, contentVariables } = templateParams;

    const messageParams = {
      from,
      to: formattedTo,
    };

    if (contentSid) {
      messageParams.contentSid = contentSid;
    }
    if (contentVariables) {
      messageParams.contentVariables = contentVariables;
    }

    if (!contentSid && !templateParams.body) {
      return { success: false, error: 'Either contentSid or body is required' };
    }

    if (!contentSid) {
      messageParams.body = templateParams.body;
    }

    const message = await twilioClient.messages.create(messageParams);

    await logWhatsAppCommunication({
      leadId,
      employeeId,
      direction: 'outbound',
      content: templateParams.body || `[Template: ${contentSid}]`,
      status: 'sent',
      metadata: {
        ...metadata,
        twilioMessageSid: message.sid,
        twilioStatus: message.status,
        channel: WHATSAPP_TYPE,
        contentSid: contentSid || null,
        to: formattedTo,
        from,
      },
    });

    return {
      success: true,
      sid: message.sid,
      status: message.status,
    };
  } catch (error) {
    logger.error('sendWhatsAppTemplate error:', error.message);
    return { success: false, error: error.message };
  }
};

const parseIncomingWhatsApp = (body) => {
  const trimmed = (body || '').trim().toLowerCase();

  const keywordMap = {
    oui: 'yes',
    yes: 'yes',
    y: 'yes',
    '1': 'yes',
    accept: 'yes',
    accepte: 'yes',
    non: 'no',
    no: 'no',
    n: 'no',
    '2': 'no',
    decline: 'no',
    refuse: 'no',
    arrive: 'arrive',
    arrivee: 'arrive',
    termine: 'termine',
    stop: 'stop',
    arret: 'stop',
    desabonner: 'stop',
    aide: 'help',
    help: 'help',
    info: 'info',
  };

  if (keywordMap[trimmed]) {
    return { action: keywordMap[trimmed], raw: trimmed };
  }

  return { action: null, raw: trimmed };
};

async function logWhatsAppCommunication({
  leadId = null,
  employeeId = null,
  direction = 'outbound',
  content = null,
  status = 'sent',
  attachments = [],
  metadata = {},
}) {
  try {
    await db.insert(communicationLogsTable).values({
      leadId: leadId || null,
      employeeId: employeeId || null,
      type: WHATSAPP_TYPE,
      direction,
      content: normalizeCommunicationText(content),
      attachments: normalizeCommunicationAttachments(attachments),
      status: normalizeCommunicationStatus(status),
      metadata: normalizeCommunicationMetadata(metadata),
    });
  } catch (err) {
    logger.error('Failed to log WhatsApp communication:', err.message);
  }
}

const i18n = {
  fr: {
    welcome: 'Bonjour ! Bienvenue chez ImmoGestion. Je suis votre assistant virtuel WhatsApp.',
    askReason: 'Quelle est la raison de votre demenagement ?',
    askBudget: 'Quel est votre budget mensuel pour le loyer ? (ex: 1200)',
    askBuilding: 'Quel immeuble vous interesse ?',
    suggestVisit: 'Souhaitez-vous planifier une visite ? (Repondez oui ou non)',
    visitBooked: 'Votre visite est confirmee ! Vous recevrez un SMS de confirmation sous peu.',
    thankYou: 'Merci d\'avoir contacte ImmoGestion ! Un agent vous recontactera bientot.',
    fallback: 'Je ne suis pas sur de comprendre. Un agent vous recontactera bientot.',
    optOut: 'Vous avez ete desabonne. Vous ne recevrez plus de messages WhatsApp de notre part.',
    help: 'Bienvenue chez ImmoGestion ! Tapez "info" pour en savoir plus sur nos logements disponibles.',
  },
  en: {
    welcome: 'Hello! Welcome to ImmoGestion. I\'m your WhatsApp virtual assistant.',
    askReason: 'What is your reason for moving?',
    askBudget: 'What is your monthly rent budget? (e.g., 1200)',
    askBuilding: 'Which building are you interested in?',
    suggestVisit: 'Would you like to schedule a visit? (Reply yes or no)',
    visitBooked: 'Your visit is confirmed! You\'ll receive an SMS confirmation shortly.',
    thankYou: 'Thank you for contacting ImmoGestion! An agent will reach out to you soon.',
    fallback: 'I\'m not sure I understand. An agent will reach out to you soon.',
    optOut: 'You have been unsubscribed. You will no longer receive WhatsApp messages from us.',
    help: 'Welcome to ImmoGestion! Type "info" to learn more about our available units.',
  },
};

function t(key, lang) {
  return (i18n[lang] && i18n[lang][key]) || i18n.fr[key] || key;
}

function detectLanguage(text) {
  const lower = (text || '').toLowerCase();
  const englishWords = ['hello', 'hi', 'english', 'yes', 'no', 'the', 'i am', 'i\'m', 'move', 'work', 'student', 'budget', 'visit', 'apartment', 'rent', 'pet'];
  const matchCount = englishWords.filter((w) => lower.includes(w)).length;
  return matchCount >= 2 ? 'en' : 'fr';
}

module.exports = {
  initWhatsApp,
  isReady,
  sendWhatsAppMessage,
  sendWhatsAppTemplate,
  parseIncomingWhatsApp,
  logWhatsAppCommunication,
  formatWhatsAppRecipient,
  getWhatsAppSender,
  t,
  detectLanguage,
  i18n,
  WHATSAPP_TYPE,
};
