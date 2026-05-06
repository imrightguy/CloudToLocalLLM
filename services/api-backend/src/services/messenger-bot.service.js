/**
 * Messenger Bot Service — Conversation State Machine
 *
 * Autonomous Facebook Messenger bot for ImmoGestion.
 * French-first, auto-detects English. Logs all comms to communicationLogsTable.
 *
 * States: NEW → ASKED_LANGUAGE → ASKED_REASON → ASKED_EMPLOYMENT →
 *         ASKED_OCCUPANTS → ASKED_PETS → ASKED_BUDGET → ASKED_BUILDING →
 *         SUGGEST_VISIT → DONE
 */

const {
  eq, and, lte, sql, asc, inArray,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  normalizeCommunicationAttachments,
  normalizeCommunicationMetadata,
  normalizeCommunicationStatus,
  normalizeCommunicationText,
} = require('../utils/communication');
const {
  leadsTable,
  buildingsTable,
  unitsTable,
  employeesTable,
  employeeAssignmentsTable,
  employeeSchedulesTable,
  visitsTable,
  communicationLogsTable,
  messengerConversationsTable,
} = require('../database/schema');

const fbService = require('./facebook.service');
const smsService = require('./sms.service');
const {
  checkVisitConflict,
  checkScheduleAvailability,
} = require('../controllers/visit.controller');
const { generateConfirmationToken } = require('../controllers/tenant-confirmation.controller');
const logger = require('../utils/logger');

// ─── Conversation States ───
const STATES = {
  NEW: 'NEW',
  ASKED_LANGUAGE: 'ASKED_LANGUAGE',
  ASKED_REASON: 'ASKED_REASON',
  ASKED_EMPLOYMENT: 'ASKED_EMPLOYMENT',
  ASKED_OCCUPANTS: 'ASKED_OCCUPANTS',
  ASKED_PETS: 'ASKED_PETS',
  ASKED_BUDGET: 'ASKED_BUDGET',
  ASKED_BUILDING: 'ASKED_BUILDING',
  SUGGEST_VISIT: 'SUGGEST_VISIT',
  DONE: 'DONE',
};

// ─── In-memory state store ───
const conversations = new Map();

// ─── i18n strings ───
const i18n = {
  fr: {
    welcome: '👋 Bonjour ! Bienvenue chez ImmoGestion. Je suis votre assistant virtuel.',
    askLanguage: 'Dans quelle langue souhaitez-vous communiquer ?',
    askReason: 'Quelle est la raison de votre déménagement ?',
    askEmployment: 'Quelle est votre situation d\'emploi actuelle ?',
    askOccupants: 'Combien de personnes occuperont le logement ?',
    askPets: 'Avez-vous des animaux de compagnie ?',
    askBudget: 'Quel est votre budget mensuel pour le loyer ? (ex: 1200)',
    askBuilding: 'Quel immeuble vous intéresse ?',
    noListings: 'Désolé, je n\'ai pas de logements disponibles correspondant à vos critères. Je transfère votre demande à Simon.',
    suggestVisit: 'Souhaitez-vous planifier une visite ?',
    visitBooked: '✅ Votre visite est confirmée ! Vous recevrez un SMS de confirmation sous peu.',
    thankYou: 'Merci d\'avoir contacté ImmoGestion ! Simon prendra contact avec vous bientôt. 😊',
    fallback: 'Je ne suis pas sûr de comprendre. Je vais transférer votre demande à Simon.',
    noPhoneNumber: 'Pour réserver une visite, nous aurons besoin de votre numéro de téléphone. Veuillez nous contacter par téléphone ou sur notre site web.',
  },
  en: {
    welcome: '👋 Hello! Welcome to ImmoGestion. I\'m your virtual assistant.',
    askLanguage: 'What language would you like to use?',
    askReason: 'What is your reason for moving?',
    askEmployment: 'What is your current employment status?',
    askOccupants: 'How many people will be living in the unit?',
    askPets: 'Do you have any pets?',
    askBudget: 'What is your monthly rent budget? (e.g., 1200)',
    askBuilding: 'Which building are you interested in?',
    noListings: 'Sorry, I don\'t have any available units matching your criteria. I\'ll forward your request to Simon.',
    suggestVisit: 'Would you like to schedule a visit?',
    visitBooked: '✅ Your visit is confirmed! You\'ll receive an SMS confirmation shortly.',
    thankYou: 'Thank you for contacting ImmoGestion! Simon will reach out to you soon. 😊',
    fallback: 'I\'m not sure I understand. I\'ll forward your request to Simon.',
    noPhoneNumber: 'To book a visit, we\'ll need your phone number. Please contact us by phone or on our website.',
  },
};

// ─── Helpers ───

function t(key, lang) {
  return (i18n[lang] && i18n[lang][key]) || i18n.fr[key] || key;
}

/**
 * Simple language detection heuristic.
 * If the text contains common English words, return 'en'; otherwise 'fr'.
 */
function detectLanguage(text) {
  const lower = (text || '').toLowerCase();
  const englishWords = ['hello', 'hi', 'english', 'yes', 'no', 'the', 'i am', 'i\'m', 'move', 'work', 'student', 'budget', 'visit', 'apartment', 'rent', 'pet'];
  const matchCount = englishWords.filter((w) => lower.includes(w)).length;
  return matchCount >= 2 ? 'en' : 'fr';
}

/**
 * Parse a dollar amount from free text. Returns cents.
 */
function parseBudget(text) {
  const cleaned = (text || '').replace(/[^0-9.,]/g, '').replace(',', '.');
  const dollars = parseFloat(cleaned);
  return Number.isNaN(dollars) ? null : Math.round(dollars * 100);
}

/**
 * Normalize a persisted conversation row into the in-memory shape.
 */
function hydrateConversation(row, senderId) {
  const conversationData = row?.conversationData && typeof row.conversationData === 'object' ? row.conversationData : {};
  const communicationLogIds = Array.isArray(conversationData.communicationLogIds) ? conversationData.communicationLogIds : [];

  return {
    state: row?.state || STATES.NEW,
    leadId: row?.leadId || null,
    lastActivityAt: row?.lastActivityAt || new Date(),
    data: {
      ...conversationData,
      language: row?.language || conversationData.language || 'fr',
      fbSenderId: senderId,
      firstName: row?.firstName ?? conversationData.firstName ?? null,
      lastName: row?.lastName ?? conversationData.lastName ?? null,
      buildingId: row?.selectedBuildingId ?? conversationData.buildingId ?? null,
      unitId: row?.selectedUnitId ?? conversationData.unitId ?? null,
      communicationLogIds,
    },
  };
}

async function persistConversation(senderId, conv) {
  const payload = {
    senderId,
    state: conv.state || STATES.NEW,
    leadId: conv.leadId || null,
    language: conv.data?.language || 'fr',
    firstName: conv.data?.firstName || null,
    lastName: conv.data?.lastName || null,
    selectedBuildingId: conv.data?.buildingId || null,
    selectedUnitId: conv.data?.unitId || null,
    lastActivityAt: conv.lastActivityAt || new Date(),
    conversationData: {
      ...conv.data,
      communicationLogIds: Array.isArray(conv.data?.communicationLogIds) ? conv.data.communicationLogIds : [],
    },
    isActive: true,
    updatedAt: new Date(),
  };

  try {
    await db.insert(messengerConversationsTable).values({
      ...payload,
      createdAt: new Date(),
    }).onConflictDoUpdate({
      target: messengerConversationsTable.senderId,
      set: {
        state: payload.state,
        leadId: payload.leadId,
        language: payload.language,
        firstName: payload.firstName,
        lastName: payload.lastName,
        selectedBuildingId: payload.selectedBuildingId,
        selectedUnitId: payload.selectedUnitId,
        lastActivityAt: payload.lastActivityAt,
        conversationData: payload.conversationData,
        isActive: payload.isActive,
        updatedAt: payload.updatedAt,
      },
    });
  } catch (err) {
    logger.error('[MessengerBot] Failed to persist conversation state:', err.message);
  }
}

async function loadConversation(senderId) {
  const existing = conversations.get(senderId);
  if (existing) {
    return existing;
  }

  try {
    const [row] = await db
      .select()
      .from(messengerConversationsTable)
      .where(eq(messengerConversationsTable.senderId, senderId))
      .limit(1);

    const conversation = row ? hydrateConversation(row, senderId) : {
      state: STATES.NEW,
      leadId: null,
      lastActivityAt: new Date(),
      data: { language: 'fr', fbSenderId: senderId, communicationLogIds: [] },
    };

    conversations.set(senderId, conversation);
    return conversation;
  } catch (err) {
    logger.error('[MessengerBot] Failed to load conversation state:', err.message);
  }

  const fallback = {
    state: STATES.NEW,
    leadId: null,
    lastActivityAt: new Date(),
    data: { language: 'fr', fbSenderId: senderId, communicationLogIds: [] },
  };
  conversations.set(senderId, fallback);
  return fallback;
}

async function getConversation(senderId) {
  return loadConversation(senderId);
}

async function resetConversation(senderId) {
  conversations.delete(senderId);

  try {
    await db.delete(messengerConversationsTable).where(eq(messengerConversationsTable.senderId, senderId));
  } catch (err) {
    logger.error('[MessengerBot] Failed to reset conversation state:', err.message);
  }
}

/**
 * Log a communication to the DB.
 */
async function logCommunication({
  senderId, leadId, employeeId, type, direction, content, status, attachments, metadata,
}) {
  try {
    const insertQuery = db.insert(communicationLogsTable).values({
      leadId: leadId || null,
      employeeId: employeeId || null,
      type: type || 'fb_messenger',
      direction: direction || 'outbound',
      content: normalizeCommunicationText(content),
      attachments: normalizeCommunicationAttachments(attachments),
      status: normalizeCommunicationStatus(status),
      metadata: normalizeCommunicationMetadata(metadata),
    });

    const insertedRows = typeof insertQuery.returning === 'function'
      ? await insertQuery.returning({ id: sql`id` })
      : await insertQuery;

    if (senderId && insertedRows?.[0]?.id) {
      const conv = await getConversation(senderId);
      conv.data.communicationLogIds = conv.data.communicationLogIds || [];
      conv.data.communicationLogIds.push(insertedRows[0].id);
      conv.lastActivityAt = new Date();
      await persistConversation(senderId, conv);
    }
  } catch (err) {
    logger.error('[MessengerBot] Failed to log communication:', err.message);
  }
}

async function backfillConversationLead(senderId, leadId) {
  const conv = conversations.get(senderId);
  const communicationLogIds = conv?.data?.communicationLogIds || [];

  if (!leadId || communicationLogIds.length === 0) {
    return;
  }

  try {
    await db
      .update(communicationLogsTable)
      .set({ leadId })
      .where(inArray(sql`id`, communicationLogIds));
  } catch (err) {
    logger.error('[MessengerBot] Failed to backfill Messenger communications:', err.message);
  }
}

const handleIncomingAttachment = async (senderId, attachments = []) => {
  const conv = await getConversation(senderId);
  const normalizedAttachments = Array.isArray(attachments) ? attachments : [];
  const attachmentTypes = normalizedAttachments
    .map((attachment) => attachment?.type)
    .filter(Boolean);
  const uniqueTypes = [...new Set(attachmentTypes)];
  const typeSummary = uniqueTypes.length > 0 ? ` (${uniqueTypes.join(', ')})` : '';

  await logCommunication({
    senderId,
    leadId: conv.leadId,
    type: 'fb_messenger',
    direction: 'inbound',
    content: `Pièce jointe Messenger reçue${typeSummary}`,
    status: 'received',
    attachments: normalizedAttachments,
    metadata: {
      attachmentCount: normalizedAttachments.length,
      attachmentTypes: uniqueTypes,
    },
  });
};

// ─── DB Queries ───

/**
 * Query vacant units matching criteria.
 * @param {Object} criteria - { budgetCents, occupants, pets, buildingId }
 * @returns {Promise<Array>} Matching units with building info
 */
async function getAvailableListings(criteria) {
  const conditions = [eq(unitsTable.status, 'vacant'), eq(unitsTable.isActive, true)];

  if (criteria.budgetCents) {
    conditions.push(lte(unitsTable.rentCents, criteria.budgetCents));
  }
  if (criteria.occupants) {
    // At least occupants count bedrooms (or null if unspecified)
    conditions.push(
      sql`(${unitsTable.bedrooms} IS NULL OR ${unitsTable.bedrooms} >= ${criteria.occupants})`,
    );
  }
  if (criteria.buildingId) {
    conditions.push(eq(unitsTable.buildingId, criteria.buildingId));
  }

  const results = await db
    .select({
      unit: unitsTable,
      building: buildingsTable,
    })
    .from(unitsTable)
    .innerJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
    .where(and(...conditions))
    .limit(10);

  return results;
}

/**
 * Get available visit time slots for a building on a given day.
 * @param {string} buildingId
 * @param {Date} date
 * @returns {Promise<Array<{employeeId, employeeName, startTime, endTime}>>}
 */
async function getVisitSlots(buildingId, date) {
  const dayOfWeek = date.getDay() === 0 ? 6 : date.getDay() - 1; // Mon=0 … Sun=6

  const schedules = await db
    .select({
      scheduleId: employeeSchedulesTable.id,
      employeeId: employeeSchedulesTable.employeeId,
      dayOfWeek: employeeSchedulesTable.dayOfWeek,
      startTime: employeeSchedulesTable.startTime,
      endTime: employeeSchedulesTable.endTime,
      firstName: employeesTable.firstName,
      lastName: employeesTable.lastName,
      phone: employeesTable.phone,
    })
    .from(employeeSchedulesTable)
    .innerJoin(employeesTable, eq(employeeSchedulesTable.employeeId, employeesTable.id))
    .innerJoin(
      employeeAssignmentsTable,
      eq(employeeSchedulesTable.employeeId, employeeAssignmentsTable.employeeId),
    )
    .where(
      and(
        eq(employeeAssignmentsTable.buildingId, buildingId),
        eq(employeeSchedulesTable.dayOfWeek, dayOfWeek),
        eq(employeeSchedulesTable.isActive, true),
        eq(employeesTable.isActive, true),
        eq(employeeAssignmentsTable.isActive, true),
      ),
    )
    .orderBy(asc(employeeSchedulesTable.startTime))
    .limit(5);

  return schedules;
}

/**
 * Create a lead in the DB from collected conversation data.
 * @param {string} senderId - FB sender PSID
 * @param {Object} conversationData - All collected data
 * @returns {Promise<Object>} Created lead
 */
async function createLeadFromConversation(senderId, conversationData) {
  const {
    language, reason, employment, occupants, pets, budgetCents, buildingId, unitId, firstName, lastName,
  } = conversationData;

  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim() || `FB User ${senderId.slice(-6)}`;

  const tags = [];
  if (reason) {tags.push(reason);}
  if (employment) {tags.push(employment);}
  if (pets === 'yes') {tags.push('pets');}

  const notes = [
    reason && `Raison: ${reason}`,
    employment && `Emploi: ${employment}`,
    occupants && `Occupants: ${occupants}`,
    pets && `Animaux: ${pets}`,
    budgetCents && `Budget: $${(budgetCents / 100).toFixed(0)}/mois`,
    'Source: Facebook Messenger',
    `FB PSID: ${senderId}`,
  ]
    .filter(Boolean)
    .join('\n');

  const [lead] = await db
    .insert(leadsTable)
    .values({
      fullName,
      language: language || 'fr',
      source: 'facebook',
      stage: 'nouveau',
      budgetCents: budgetCents || null,
      buildingId: buildingId || null,
      unitId: unitId || null,
      notes,
      tags,
    })
    .returning();

  return lead;
}

// ─── State Machine Handlers ───

/**
 * Handle an incoming text message from a user.
 * @param {string} senderId - Facebook sender PSID
 * @param {string} messageText - The user's message
 */
const handleIncomingMessage = async (senderId, messageText) => {
  const text = (messageText || '').trim();
  const conv = await getConversation(senderId);
  const lang = conv.data.language || 'fr';
  conv.lastActivityAt = new Date();

  // Log inbound message
  await logCommunication({
    senderId,
    leadId: conv.leadId,
    type: 'fb_messenger',
    direction: 'inbound',
    content: text,
    status: 'received',
  });

  try {
    switch (conv.state) {
      case STATES.NEW:
        await handleNew(senderId, conv, text);
        break;
      case STATES.ASKED_LANGUAGE:
        await handleLanguage(senderId, conv, text);
        break;
      case STATES.ASKED_REASON:
        await handleReason(senderId, conv, text);
        break;
      case STATES.ASKED_EMPLOYMENT:
        await handleEmployment(senderId, conv, text);
        break;
      case STATES.ASKED_OCCUPANTS:
        await handleOccupants(senderId, conv, text);
        break;
      case STATES.ASKED_PETS:
        await handlePets(senderId, conv, text);
        break;
      case STATES.ASKED_BUDGET:
        await handleBudget(senderId, conv, text);
        break;
      case STATES.ASKED_BUILDING:
        await handleBuilding(senderId, conv, text);
        break;
      case STATES.SUGGEST_VISIT:
        await handleSuggestVisit(senderId, conv, text);
        break;
      case STATES.DONE:
        await fbService.sendTextMessage(senderId, t('thankYou', lang));
        await logCommunication({
          senderId,
          leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: t('thankYou', lang),
        });
        break;
      default:
        await fbService.sendTextMessage(senderId, t('fallback', lang));
        await logCommunication({
          senderId,
          leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: t('fallback', lang),
        });
        conv.state = STATES.DONE;
    }
  } catch (err) {
    logger.error('[MessengerBot] Error handling message:', err);
    await fbService.sendTextMessage(
      senderId,
      lang === 'en'
        ? 'Sorry, something went wrong. Simon will be notified and get back to you.'
        : 'Désolé, une erreur est survenue. Simon sera informé et vous recontactera.',
    );
  } finally {
    await persistConversation(senderId, conv);
  }
};

// ─── Individual State Handlers ───

async function handleNew(senderId, conv, _text) {
  // Try to fetch FB profile for the user
  try {
    const profile = await fbService.getUserProfile(senderId);
    conv.data.firstName = profile.firstName;
    conv.data.lastName = profile.lastName;
    conv.data.locale = profile.locale;
  } catch (err) {
    logger.warn('[MessengerBot] Could not fetch user profile:', err.message);
  }

  // Send welcome + ask language
  const msg = t('welcome', 'fr');
  await fbService.sendTextMessage(senderId, msg);
  await logCommunication({ senderId, type: 'fb_messenger', direction: 'outbound', content: msg });

  await fbService.sendQuickReplies(senderId, t('askLanguage', 'fr'), [
    { title: '🇫🇷 Français', payload: 'LANG_FR' },
    { title: '🇬🇧 English', payload: 'LANG_EN' },
  ]);
  await logCommunication({ senderId, type: 'fb_messenger', direction: 'outbound', content: t('askLanguage', 'fr') });

  conv.state = STATES.ASKED_LANGUAGE;
}

async function handleLanguage(senderId, conv, text) {
  const lower = text.toLowerCase();

  if (lower.includes('english') || lower.includes('en') || lower.includes('🇬🇧')) {
    conv.data.language = 'en';
  } else {
    conv.data.language = 'fr';
  }

  const lang = conv.data.language;
  conv.state = STATES.ASKED_REASON;

  const msg = t('askReason', lang);
  await fbService.sendQuickReplies(senderId, msg, [
    { title: lang === 'en' ? '💼 Work' : '💼 Travail', payload: 'REASON_WORK' },
    { title: lang === 'en' ? '🎓 Studies' : '🎓 Études', payload: 'REASON_STUDY' },
    { title: lang === 'en' ? '👨‍👩‍👧 Family' : '👨‍👩‍👧 Famille', payload: 'REASON_FAMILY' },
    { title: lang === 'en' ? '📦 Other' : '📦 Autre', payload: 'REASON_OTHER' },
  ]);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handleReason(senderId, conv, text) {
  const lang = conv.data.language;
  conv.data.reason = text;
  conv.state = STATES.ASKED_EMPLOYMENT;

  const msg = t('askEmployment', lang);
  await fbService.sendQuickReplies(senderId, msg, [
    { title: lang === 'en' ? '💼 Employed' : '💼 Employé(e)', payload: 'EMPLOYED' },
    { title: lang === 'en' ? '🎓 Student' : '🎓 Étudiant(e)', payload: 'STUDENT' },
    { title: lang === 'en' ? '🏠 Retired' : '🏠 Retraité(e)', payload: 'RETIRED' },
    { title: lang === 'en' ? '📦 Other' : '📦 Autre', payload: 'EMPLOY_OTHER' },
  ]);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handleEmployment(senderId, conv, text) {
  const lang = conv.data.language;
  conv.data.employment = text;
  conv.state = STATES.ASKED_OCCUPANTS;

  const msg = t('askOccupants', lang);
  await fbService.sendQuickReplies(senderId, msg, [
    { title: '1', payload: 'OCC_1' },
    { title: '2', payload: 'OCC_2' },
    { title: '3', payload: 'OCC_3' },
    { title: '4+', payload: 'OCC_4+' },
  ]);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handleOccupants(senderId, conv, text) {
  const lang = conv.data.language;
  const match = text.match(/\d+/);
  conv.data.occupants = match ? parseInt(match[0]) : 1;
  conv.state = STATES.ASKED_PETS;

  const msg = t('askPets', lang);
  await fbService.sendQuickReplies(senderId, msg, [
    { title: lang === 'en' ? '🐕 Yes' : '🐕 Oui', payload: 'PETS_YES' },
    { title: lang === 'en' ? '✅ No' : '✅ Non', payload: 'PETS_NO' },
  ]);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handlePets(senderId, conv, text) {
  const lang = conv.data.language;
  const lower = text.toLowerCase();
  conv.data.pets = (lower.includes('yes') || lower.includes('oui') || lower.includes('🐕')) ? 'yes' : 'no';
  conv.state = STATES.ASKED_BUDGET;

  const msg = t('askBudget', lang);
  await fbService.sendTextMessage(senderId, msg);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handleBudget(senderId, conv, text) {
  const lang = conv.data.language;
  const budgetCents = parseBudget(text);

  if (!budgetCents) {
    const retryMsg = lang === 'en'
      ? 'I couldn\'t understand the amount. Please enter a number (e.g., 1200).'
      : 'Je n\'ai pas pu comprendre le montant. Veuillez entrer un nombre (ex: 1200).';
    await fbService.sendTextMessage(senderId, retryMsg);
    await logCommunication({
      senderId,
      leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: retryMsg,
    });
    return; // Stay in ASKED_BUDGET
  }

  conv.data.budgetCents = budgetCents;

  // Create lead now with all collected info
  try {
    const lead = await createLeadFromConversation(senderId, conv.data);
    conv.leadId = lead.id;
    await backfillConversationLead(senderId, lead.id);
  } catch (err) {
    logger.error('[MessengerBot] Failed to create lead:', err.message);
  }

  // Search for matching listings
  const listings = await getAvailableListings({
    budgetCents,
    occupants: conv.data.occupants,
    pets: conv.data.pets,
  });

  if (listings.length === 0) {
    const noMsg = t('noListings', lang);
    await fbService.sendTextMessage(senderId, noMsg);
    await logCommunication({
      senderId,
      leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: noMsg,
    });
    conv.state = STATES.DONE;
    return;
  }

  // Build generic template cards for listings
  const elements = listings.slice(0, 4).map((l) => {
    const rentDollars = (l.unit.rentCents / 100).toFixed(0);
    const subtitleParts = [
      l.building.address,
      l.unit.bedrooms ? `${l.unit.bedrooms} ${lang === 'en' ? 'bedroom(s)' : 'chambre(s)'}` : '',
      l.unit.squareFeet ? `${l.unit.squareFeet} sq ft` : '',
    ].filter(Boolean);

    return {
      title: `${l.building.name} — ${l.unit.label}`,
      subtitle: `${subtitleParts.join(' · ')} — $${rentDollars}$/mois`,
      buttons: [
        {
          type: 'postback',
          title: lang === 'en' ? '📍 Interested' : '📍 Intéressé(e)',
          payload: `SELECT_UNIT_${l.unit.id}_${l.building.id}`,
        },
      ],
    };
  });

  await fbService.sendGenericTemplate(senderId, elements);
  await logCommunication({
    senderId,
    leadId: conv.leadId,
    type: 'fb_messenger',
    direction: 'outbound',
    content: `[Listings] ${listings.length} unit(s) shown`,
    metadata: { unitIds: listings.map((l) => l.unit.id) },
  });

  conv.state = STATES.ASKED_BUILDING;
}

async function handleBuilding(senderId, conv, _text) {
  const lang = conv.data.language;

  // Check if user selected a unit from template (postback-style text fallback)
  // Otherwise proceed to suggest visit
  conv.state = STATES.SUGGEST_VISIT;

  const msg = t('suggestVisit', lang);
  await fbService.sendQuickReplies(senderId, msg, [
    { title: lang === 'en' ? '✅ Yes, schedule visit' : '✅ Oui, planifier une visite', payload: 'VISIT_YES' },
    { title: lang === 'en' ? '❌ No thanks' : '❌ Non merci', payload: 'VISIT_NO' },
  ]);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
  });
}

async function handleSuggestVisit(senderId, conv, text) {
  const lang = conv.data.language;
  const lower = text.toLowerCase();

  const wantsVisit = lower.includes('yes') || lower.includes('oui') || lower.includes('✅') || lower.includes('schedule') || lower.includes('planifier');

  if (!wantsVisit) {
    const msg = t('thankYou', lang);
    await fbService.sendTextMessage(senderId, msg);
    await logCommunication({
      senderId,
      leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: msg,
    });
    conv.state = STATES.DONE;
    return;
  }

  // We need a buildingId and unitId to schedule. If none selected, use first available.
  if (!conv.data.buildingId || !conv.data.unitId) {
    const listings = await getAvailableListings({
      budgetCents: conv.data.budgetCents,
      occupants: conv.data.occupants,
    });

    if (listings.length === 0) {
      const noListingsMsg = t('noListings', lang);
      await fbService.sendTextMessage(senderId, noListingsMsg);
      await logCommunication({
        senderId,
        leadId: conv.leadId,
        type: 'fb_messenger',
        direction: 'outbound',
        content: noListingsMsg,
      });
      conv.state = STATES.DONE;
      return;
    }

    conv.data.unitId = listings[0].unit.id;
    conv.data.buildingId = listings[0].building.id;
  }

  // Get next weekday for visit
  const now = new Date();
  const visitDate = new Date(now);
  visitDate.setDate(visitDate.getDate() + 1);
  // Move to next weekday if weekend
  while (visitDate.getDay() === 0 || visitDate.getDay() === 6) {
    visitDate.setDate(visitDate.getDate() + 1);
  }

  // Get visit slots
  const slots = await getVisitSlots(conv.data.buildingId, visitDate);
  const validatedSlots = [];

  for (const slot of slots) {
    const candidateDateTime = new Date(visitDate);
    const [candidateHours, candidateMinutes] = slot.startTime.split(':').map(Number);
    candidateDateTime.setHours(candidateHours, candidateMinutes, 0, 0);

    const scheduleError = await checkScheduleAvailability(slot.employeeId, conv.data.buildingId, candidateDateTime, 30);
    if (scheduleError) {
      continue;
    }

    const conflict = await checkVisitConflict(slot.employeeId, candidateDateTime, 30);
    if (conflict) {
      continue;
    }

    validatedSlots.push(slot);
  }

  if (validatedSlots.length === 0) {
    const noSlotsMsg = lang === 'en'
      ? 'No available time slots found for this building. Simon will contact you to arrange a visit.'
      : 'Aucun créneau disponible pour cet immeuble. Simon vous contactera pour organiser une visite.';
    await fbService.sendTextMessage(senderId, noSlotsMsg);
    await logCommunication({
      senderId,
      leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: noSlotsMsg,
    });
    conv.state = STATES.DONE;
    return;
  }

  // Use first available slot
  const slot = validatedSlots[0];
  const visitDateTime = new Date(visitDate);
  const [hours, minutes] = slot.startTime.split(':').map(Number);
  visitDateTime.setHours(hours, minutes, 0, 0);

  // Update lead with building/unit assignment
  if (conv.leadId) {
    try {
      await db
        .update(leadsTable)
        .set({
          buildingId: conv.data.buildingId,
          unitId: conv.data.unitId,
          assignedEmployeeId: slot.employeeId,
          stage: 'visite_planifiee',
          updatedAt: new Date(),
        })
        .where(eq(leadsTable.id, conv.leadId));
    } catch (err) {
      logger.error('[MessengerBot] Failed to update lead:', err.message);
    }
  }

  let visit = null;
  if (conv.leadId) {
    try {
      [visit] = await db
        .insert(visitsTable)
        .values({
          unitId: conv.data.unitId,
          employeeId: slot.employeeId,
          leadId: conv.leadId,
          dateTime: visitDateTime,
          durationMinutes: 30,
          status: 'scheduled',
          notes: 'Visit scheduled via Facebook Messenger bot',
          confirmationToken: generateConfirmationToken(),
        })
        .returning();
    } catch (err) {
      logger.error('[MessengerBot] Failed to create visit:', err.message);
    }
  }

  // Format visit date string
  const formattedDate = visitDateTime.toLocaleDateString(lang === 'en' ? 'en-CA' : 'fr-CA', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const visitMsg = lang === 'en'
    ? `📅 Your visit is scheduled for ${formattedDate} with ${slot.firstName} ${slot.lastName}.`
    : `📅 Votre visite est planifiée pour le ${formattedDate} avec ${slot.firstName} ${slot.lastName}.`;

  await fbService.sendTextMessage(senderId, visitMsg);
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: visitMsg,
  });

  logger.info('[MessengerBot] message-to-visit workflow scheduled visit', {
    leadId: conv.leadId,
    visitId: visit?.id || null,
    buildingId: conv.data.buildingId,
    unitId: conv.data.unitId,
    employeeId: slot.employeeId,
    dateTime: visitDateTime.toISOString(),
  });

  if (visit) {
    try {
      const visitConfirmationResult = await smsService.sendVisitConfirmation(visit.id);
      const tenantConfirmationResult = await smsService.sendTenantConfirmationRequest(visit.id);

      if (visitConfirmationResult.success && tenantConfirmationResult.success) {
        logger.info('[MessengerBot] message-to-visit confirmation workflow dispatched', {
          visitId: visit.id,
          leadId: conv.leadId,
          employeeSuccess: true,
          tenantSuccess: true,
        });
      } else {
        logger.warn('[MessengerBot] message-to-visit confirmation workflow had delivery failures', {
          visitId: visit.id,
          leadId: conv.leadId,
          employeeSuccess: visitConfirmationResult.success,
          tenantSuccess: tenantConfirmationResult.success,
          employeeError: visitConfirmationResult.error || null,
          tenantError: tenantConfirmationResult.error || null,
        });
      }
    } catch (err) {
      logger.error('[MessengerBot] Failed to send visit confirmation workflow:', err.message);
    }

    try {
      const [unitDetails] = await db
        .select()
        .from(unitsTable)
        .where(eq(unitsTable.id, conv.data.unitId))
        .limit(1);

      const isOccupied = unitDetails?.status === 'occupied' || unitDetails?.tenantPhone;
      if (isOccupied) {
        const occupantAccessResult = await smsService.sendOccupantAccessRequest(visit.id);
        if (!occupantAccessResult.success) {
          logger.warn('[MessengerBot] Occupant access request failed', {
            visitId: visit.id,
            leadId: conv.leadId,
            error: occupantAccessResult.error || null,
          });
        }
      }
    } catch (err) {
      logger.error('[MessengerBot] Failed to send occupant access request:', err.message);
    }
  }

  if (!conv.data.phone) {
    const noPhoneMsg = t('noPhoneNumber', lang);
    await fbService.sendTextMessage(senderId, noPhoneMsg);
    await logCommunication({
      senderId,
      leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: noPhoneMsg,
    });
  }

  await fbService.sendTextMessage(senderId, t('visitBooked', lang));
  await logCommunication({
    senderId,
    leadId: conv.leadId, type: 'fb_messenger', direction: 'outbound', content: t('visitBooked', lang),
  });

  conv.state = STATES.DONE;
}

// ─── Postback Handler (Quick Reply taps) ───

/**
 * Handle quick reply / postback button taps.
 * @param {string} senderId - Facebook sender PSID
 * @param {string} payload - The payload string from the button
 */
const handlePostback = async (senderId, payload) => {
  const conv = await getConversation(senderId);
  const lang = conv.data.language || 'fr';

  // Log inbound postback
  await logCommunication({
    senderId,
    leadId: conv.leadId,
    type: 'fb_messenger',
    direction: 'inbound',
    content: `[Postback] ${payload}`,
    status: 'received',
  });

  // Handle language selection postbacks
  if (payload === 'LANG_FR') {
    await handleIncomingMessage(senderId, 'Français');
    return;
  }
  if (payload === 'LANG_EN') {
    await handleIncomingMessage(senderId, 'English');
    return;
  }

  // Handle reason postbacks
  if (payload === 'REASON_WORK' || payload === 'REASON_STUDY' || payload === 'REASON_FAMILY' || payload === 'REASON_OTHER') {
    const reasonMap = {
      REASON_WORK: lang === 'en' ? 'work' : 'travail',
      REASON_STUDY: lang === 'en' ? 'study' : 'études',
      REASON_FAMILY: lang === 'en' ? 'family' : 'famille',
      REASON_OTHER: lang === 'en' ? 'other' : 'autre',
    };
    await handleIncomingMessage(senderId, reasonMap[payload]);
    return;
  }

  // Handle employment postbacks
  if (payload === 'EMPLOYED' || payload === 'STUDENT' || payload === 'RETIRED' || payload === 'EMPLOY_OTHER') {
    const empMap = {
      EMPLOYED: lang === 'en' ? 'employed' : 'employé(e)',
      STUDENT: lang === 'en' ? 'student' : 'étudiant(e)',
      RETIRED: lang === 'en' ? 'retired' : 'retraité(e)',
      EMPLOY_OTHER: lang === 'en' ? 'other' : 'autre',
    };
    await handleIncomingMessage(senderId, empMap[payload]);
    return;
  }

  // Handle occupants postbacks
  if (payload.startsWith('OCC_')) {
    await handleIncomingMessage(senderId, payload.replace('OCC_', ''));
    return;
  }

  // Handle pets postbacks
  if (payload === 'PETS_YES') {
    await handleIncomingMessage(senderId, lang === 'en' ? 'Yes' : 'Oui');
    return;
  }
  if (payload === 'PETS_NO') {
    await handleIncomingMessage(senderId, lang === 'en' ? 'No' : 'Non');
    return;
  }

  // Handle unit selection postbacks
  if (payload.startsWith('SELECT_UNIT_')) {
    const parts = payload.replace('SELECT_UNIT_', '').split('_');
    const [unitId, buildingIdRaw] = parts;
    conv.data.unitId = unitId;
    conv.data.buildingId = buildingIdRaw || null;

    // Move to visit suggestion
    conv.state = STATES.ASKED_BUILDING;
    await handleIncomingMessage(senderId, 'interested');
    return;
  }

  // Handle visit postbacks
  if (payload === 'VISIT_YES') {
    await handleIncomingMessage(senderId, lang === 'en' ? 'Yes' : 'Oui');
    return;
  }
  if (payload === 'VISIT_NO') {
    await handleIncomingMessage(senderId, lang === 'en' ? 'No' : 'Non');
    return;
  }

  // Unknown payload — treat as fallback
  logger.warn('[MessengerBot] Unknown postback payload:', payload);
  await fbService.sendTextMessage(senderId, t('fallback', lang));
};

// ─── Opt-In Handler (messaging_optins event) ───

/**
 * Handle when user opts in via Messenger (e.g., checkbox plugin).
 * @param {string} senderId - Facebook sender PSID
 * @param {string} ref - Optional ref parameter
 */
const handleOptIn = async (senderId, ref) => {
  logger.info(`[MessengerBot] Opt-in from ${senderId}, ref: ${ref}`);

  // Treat opt-in as a new conversation
  await resetConversation(senderId);
  await handleIncomingMessage(senderId, '');
};

module.exports = {
  handleIncomingMessage,
  handleIncomingAttachment,
  handlePostback,
  handleOptIn,
  getAvailableListings,
  getVisitSlots,
  createLeadFromConversation,
  detectLanguage,
};
