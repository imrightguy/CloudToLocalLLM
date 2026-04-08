const twilio = require('twilio');

let twilioClient = null;
let twilioPhoneNumber = null;
let isInitialized = false;

/**
 * Initialize the Twilio client from environment variables.
 * Must be called once at startup (e.g. in server.js).
 */
const initTwilio = () => {
  try {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    twilioPhoneNumber = process.env.TWILIO_PHONE_NUMBER || null;

    if (!accountSid || !authToken) {
      console.warn('⚠️  Twilio credentials not configured (TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN). SMS will be disabled.');
      isInitialized = false;
      return false;
    }

    twilioClient = twilio(accountSid, authToken);
    isInitialized = true;
    console.log('✅ Twilio client initialized');
    return true;
  } catch (error) {
    console.error('❌ Failed to initialize Twilio client:', error.message);
    isInitialized = false;
    return false;
  }
};

/**
 * Send an SMS via Twilio.
 * @param {string} to  - E.164 phone number (or local format, will be cleaned)
 * @param {string} body - Message text
 * @returns {Promise<{success: boolean, sid?: string, status?: string, error?: string}>}
 */
const sendSMS = async (to, body) => {
  try {
    if (!isInitialized || !twilioClient) {
      console.warn('Twilio not initialized — skipping sendSMS');
      return { success: false, error: 'Twilio not initialized' };
    }

    if (!to || !body) {
      return { success: false, error: 'Phone number and message body are required' };
    }

    const cleanedTo = to.replace(/[\s\-\(\)]/g, '');
    const from = twilioPhoneNumber;

    if (!from) {
      return { success: false, error: 'TWILIO_PHONE_NUMBER not configured' };
    }

    const message = await twilioClient.messages.create({
      body,
      from,
      to: cleanedTo,
    });

    return {
      success: true,
      sid: message.sid,
      status: message.status,
    };
  } catch (error) {
    console.error('❌ sendSMS error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Parse an incoming message body and return a normalised reply key.
 * Supports numbered replies (1, 2, 3...) and text keywords (oui, non, etc.)
 * @param {string} body - Raw incoming SMS body
 * @returns {{ action: string|null, raw: string }}
 */
const handleIncomingMessage = body => {
  try {
    const trimmed = (body || '').trim().toLowerCase();

    // Numbered replies
    const numberMap = {
      '1': 'yes',
      '2': 'no',
      '3': 'no_show',
    };

    if (numberMap[trimmed]) {
      return { action: numberMap[trimmed], raw: trimmed };
    }

    // Keyword replies (French + English)
    const keywordMap = {
      'oui': 'yes',
      'yes': 'yes',
      'y': 'yes',
      'non': 'no',
      'no': 'no',
      'n': 'no',
      'pas nécessaire': 'no',
      'pas necessaire': 'no',
      'pas interessé': 'no_interest',
      'pas interesse': 'no_interest',
      'intéressé': 'interested',
      'interesse': 'interested',
      'ne s\'est pas présenté': 'no_show',
      'ne s\'est pas presente': 'no_show',
      'absent': 'no_show',
      'no_show': 'no_show',
    };

    if (keywordMap[trimmed]) {
      return { action: keywordMap[trimmed], raw: trimmed };
    }

    return { action: null, raw: trimmed };
  } catch (error) {
    console.error('❌ handleIncomingMessage parse error:', error.message);
    return { action: null, raw: body };
  }
};

module.exports = { initTwilio, sendSMS, handleIncomingMessage };
