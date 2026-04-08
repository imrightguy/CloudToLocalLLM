/**
 * Facebook Messenger API Service
 * Meta Graph API wrapper for sending messages, templates, and fetching user profiles.
 * Uses native fetch (Node 18+).
 */

const FB_PAGE_ACCESS_TOKEN = process.env.FB_PAGE_ACCESS_TOKEN;
const FB_API_VERSION = 'v18.0';
const FB_BASE_URL = `https://graph.facebook.com/${FB_API_VERSION}`;

if (!FB_PAGE_ACCESS_TOKEN) {
  console.warn('[FB Service] FB_PAGE_ACCESS_TOKEN is not set. Facebook messaging will not work.');
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
    console.error('[FB Service] Send API error:', response.status, errorBody);
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
const sendTextMessage = async (senderId, text) => {
  return callSendAPI(senderId, {
    message: { text },
  });
};

// ─── Send Quick Replies ───

/**
 * Send a text message with quick reply buttons.
 * @param {string} senderId - Facebook sender PSID
 * @param {string} text - Message text
 * @param {Array<{title: string, payload: string}>} replies - Quick reply options (max 13)
 * @returns {Promise<Object>} Facebook API response
 */
const sendQuickReplies = async (senderId, text, replies) => {
  const quickReplies = replies.map(r => ({
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
 * @param {Array<{title: string, subtitle?: string, imageUrl?: string, defaultAction?: Object, buttons?: Array}>} elements
 * @returns {Promise<Object>} Facebook API response
 */
const sendGenericTemplate = async (senderId, elements) => {
  return callSendAPI(senderId, {
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
};

// ─── Get User Profile ───

/**
 * Fetch a Facebook user's profile info.
 * @param {string} senderId - Facebook sender PSID
 * @returns {Promise<{firstName: string, lastName: string, locale: string, profilePic: string}>}
 */
const getUserProfile = async senderId => {
  if (!FB_PAGE_ACCESS_TOKEN) {
    throw new Error('FB_PAGE_ACCESS_TOKEN is not configured');
  }

  const fields = 'first_name,last_name,locale,profile_pic';
  const url = `${FB_BASE_URL}/${senderId}?fields=${fields}&access_token=${FB_PAGE_ACCESS_TOKEN}`;

  const response = await fetch(url);
  if (!response.ok) {
    const errorBody = await response.text();
    console.error('[FB Service] User profile error:', response.status, errorBody);
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

module.exports = {
  sendTextMessage,
  sendQuickReplies,
  sendGenericTemplate,
  getUserProfile,
};
