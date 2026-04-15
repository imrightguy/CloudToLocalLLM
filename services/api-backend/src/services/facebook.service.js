const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { eq } = require('drizzle-orm');
const { leadsTable } = require('../database/schema');
/**
 * Facebook Messenger API Service
 * Meta Graph API wrapper for sending messages, templates, and fetching user profiles.
 * Uses native fetch (Node 18+).
 */

const { FB_PAGE_ACCESS_TOKEN } = process.env;
const FB_API_VERSION = 'v18.0';
const FB_BASE_URL = `https://graph.facebook.com/${FB_API_VERSION}`;

if (!FB_PAGE_ACCESS_TOKEN) {
  logger.warn('[FB Service] FB_PAGE_ACCESS_TOKEN is not set. Facebook messaging will not work.');
}

// ─── Helpers ───

async function callSendAPI(senderPsid, requestBody) {
  if (!FB_PAGE_ACCESS_TOKEN) {
    throw new Error('FB_PAGE_ACCESS_TOKEN is not configured');
  }

  const url = `${FB_BASE_URL}/me/messages?access_token=${FB_PAGE_ACCESS_TOKEN}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      recipient: { id: senderPsid },
      messaging_type: 'RESPONSE',
      ...requestBody,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    logger.error('[FB Service] Send API error:', response.status, errorBody);
    throw new Error(`Facebook Send API error ${response.status}: ${errorBody}`);
  }

  return response.json();
}

// ─── Send Text Message ───

/**
 * Send a plain text message to a user.
 * @param {string} senderId - Facebook sender PSID
 * @param {string} text - Message text (max 640 chars)
 * @returns {Promise<Object>} Facebook API response
 */
const sendTextMessage = async (senderId, text) => callSendAPI(senderId, {
  message: { text },
});

// ─── Send Quick Replies ───

/**
 * Send a text message with quick reply buttons.
 * @param {string} senderId - Facebook sender PSID
 * @param {string} text - Message text
 * @param {Array<{title: string, payload: string}>} replies - Quick reply options (max 13)
 * @returns {Promise<Object>} Facebook API response
 */
const sendQuickReplies = async (senderId, text, replies) => {
  const quickReplies = replies.map((r) => ({
    content_type: 'text',
    title: r.title,
    payload: r.payload,
  }));

  return callSendAPI(senderId, {
    message: {
      text,
      quick_replies: quickReplies,
    },
  });
};

// ─── Send Generic Template (Cards) ───

/**
 * Send a generic template with card-style elements (for listings).
 * @param {string} senderId - Facebook sender PSID
 * @param {Array<{title: string, subtitle?: string, imageUrl?: string,
 *   defaultAction?: Object, buttons?: Array}>} elements
 * @returns {Promise<Object>} Facebook API response
 */
const sendGenericTemplate = async (senderId, elements) => callSendAPI(senderId, {
  message: {
    attachment: {
      type: 'template',
      payload: {
        template_type: 'generic',
        elements,
      },
    },
  },
});

// ─── Get User Profile ───

/**
 * Fetch a Facebook user's profile info.
 * @param {string} senderId - Facebook sender PSID
 * @returns {Promise<{firstName: string, lastName: string, locale: string, profilePic: string}>}
 */
const getUserProfile = async (senderId) => {
  if (!FB_PAGE_ACCESS_TOKEN) {
    throw new Error('FB_PAGE_ACCESS_TOKEN is not configured');
  }

  const fields = 'first_name,last_name,locale,profile_pic';
  const url = `${FB_BASE_URL}/${senderId}?fields=${fields}&access_token=${FB_PAGE_ACCESS_TOKEN}`;

  const response = await fetch(url);
  if (!response.ok) {
    const errorBody = await response.text();
    logger.error('[FB Service] User profile error:', response.status, errorBody);
    throw new Error(`Facebook User API error ${response.status}: ${errorBody}`);
  }

  const profile = await response.json();
  return {
    firstName: profile.first_name || '',
    lastName: profile.last_name || '',
    locale: profile.locale || 'fr_CA',
    profilePic: profile.profile_pic || '',
  };
};

// ─── Process Lead Ad Webhook ───

/**
 * Process a Facebook Lead Ad webhook event.
 * Parses lead data, deduplicates by Facebook lead ID, and creates a lead
 * in the pipeline with source='facebook'.
 *
 * Facebook Lead Ad webhook payload (change.value):
 * {
 *   ad_id, form_id, leadgen_id, created_time,
 *   field_data: [
 *     { name: 'full_name', values: ['Jean Tremblay'] },
 *     { name: 'email', values: ['jean@example.com'] },
 *     { name: 'phone_number', values: ['+15145551234'] },
 *     { name: 'desired_unit', values: ['2.5'] },
 *     ...
 *   ],
 *   advertiser_id, page_id
 * }
 */
const processLeadAdWebhook = async (leadData) => {
  try {
    const { leadgen_id, field_data, created_time, page_id, ad_id } = leadData;

    if (!leadgen_id) {
      logger.warn('[FB Lead Ads] Missing leadgen_id, skipping');
      return { success: false, reason: 'MISSING_LEADGEN_ID' };
    }

    if (!field_data || !Array.isArray(field_data)) {
      logger.warn('[FB Lead Ads] Missing or invalid field_data for leadgen_id=%s', leadgen_id);
      return { success: false, reason: 'INVALID_FIELD_DATA' };
    }

    const getField = (name) => {
      const field = field_data.find((f) => f.name === name);
      return field?.values?.[0] || null;
    };

    const fullName = getField('full_name') || getField('name') || '';
    const email = getField('email') || getField('email_address');
    const phone = getField('phone_number') || getField('phone');
    const desiredUnit = getField('desired_unit') || getField('unit_interest');
    const budgetStr = getField('budget') || getField('budget_range');
    const notes = getField('notes') || getField('message');
    const adId = ad_id || null;
    const fbPageId = page_id || null;
    const language = getField('locale') === 'en_US' ? 'en' : 'fr';

    if (!fullName || !fullName.trim()) {
      logger.warn('[FB Lead Ads] No full_name for leadgen_id=%s, skipping', leadgen_id);
      return { success: false, reason: 'MISSING_NAME' };
    }

    let budgetCents = null;
    if (budgetStr) {
      const numeric = parseFloat(budgetStr.replace(/[^0-9.]/g, ''));
      if (!isNaN(numeric) && numeric > 0) {
        budgetCents = Math.round(numeric * 100);
      }
    }

    const dedupKey = `fb_lead_${leadgen_id}`;

    const [existing] = await db
      .select({ id: leadsTable.id })
      .from(leadsTable)
      .where(eq(leadsTable.notes, dedupKey))
      .limit(1);

    if (existing) {
      logger.info('[FB Lead Ads] Duplicate leadgen_id=%s already exists as lead %s', leadgen_id, existing.id);
      return { success: false, reason: 'DUPLICATE', existingId: existing.id };
    }

    const leadNotes = [
      `Source: Facebook Lead Ad`,
      `FB Lead ID: ${leadgen_id}`,
      adId ? `FB Ad ID: ${adId}` : null,
      fbPageId ? `FB Page ID: ${fbPageId}` : null,
      created_time ? `FB Created: ${created_time}` : null,
      notes ? `Message: ${notes}` : null,
    ].filter(Boolean).join(' | ');

    const [lead] = await db
      .insert(leadsTable)
      .values({
        fullName: fullName.trim(),
        email: email || null,
        phone: phone || null,
        budgetCents,
        desiredUnit: desiredUnit || null,
        source: 'facebook',
        stage: 'nouveau',
        notes: leadNotes,
        language,
        tags: ['facebook_lead_ad'],
      })
      .returning();

    logger.info('[FB Lead Ads] Created lead %s from leadgen_id=%s', lead.id, leadgen_id);

    return { success: true, lead };
  } catch (error) {
    logger.error('[FB Lead Ads] Error processing lead ad webhook:', error);
    return { success: false, reason: 'INTERNAL_ERROR', error: error.message };
  }
};

module.exports = {
  sendTextMessage,
  sendQuickReplies,
  sendGenericTemplate,
  getUserProfile,
  processLeadAdWebhook,
};
