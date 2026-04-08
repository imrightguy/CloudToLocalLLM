const client = require('twilio')(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

/**
 * Twilio SMS Service
 * Handles SMS sending and management for visit scheduling
 */

/**
 * Send SMS notification
 * @param {Object} options - SMS options
 * @param {string} options.to - Phone number to send to
 * @param {string} options.message - SMS message content
 * @param {string} options.from - Twilio phone number
 * @param {Object} options.metadata - Additional metadata
 * @returns {Promise<Object>} SMS result
 */
const sendSMS = async (options) => {
  try {
    const { to, message, from = process.env.TWILIO_PHONE_NUMBER, metadata = {} } = options;

    if (!to || !message) {
      throw new Error('Phone number and message are required');
    }

    // Validate phone number format
    const cleanedPhone = cleanPhoneNumber(to);
    if (!isValidPhoneNumber(cleanedPhone)) {
      throw new Error(`Invalid phone number format: ${to}`);
    }

    // Create SMS log entry
    const smsLog = {
      to: cleanedPhone,
      from: from,
      message,
      status: 'pending',
      metadata,
      sentAt: new Date()
    };

    // Send SMS via Twilio
    const twilioMessage = await client.messages.create({
      body: message,
      from: from,
      to: cleanedPhone
    });

    // Update log with Twilio response
    smsLog.sid = twilioMessage.sid;
    smsLog.status = twilioMessage.status;
    smsLog.errorMessage = twilioMessage.errorMessage || null;

    // Save to database
    await saveSMSLog(smsLog);

    return {
      success: true,
      data: {
        sid: twilioMessage.sid,
        status: twilioMessage.status,
        direction: 'outbound-api',
        from: from,
        to: cleanedPhone,
        body: message,
        dateCreated: twilioMessage.dateCreated
      },
      metadata: smsLog
    };
  } catch (error) {
    console.error('SMS sending error:', error);

    // Log failed SMS
    const failedSMSLog = {
      to: cleanPhoneNumber(options.to),
      from: options.from || process.env.TWILIO_PHONE_NUMBER,
      message: options.message,
      status: 'failed',
      error: error.message,
      metadata: options.metadata || {},
      sentAt: new Date()
    };

    await saveSMSLog(failedSMSLog);

    return {
      success: false,
      error: {
        message: 'Failed to send SMS',
        code: 'SMS_SEND_FAILED',
        details: error.message
      },
      metadata: failedSMSLog
    };
  }
};

/**
 * Schedule SMS notification
 * @param {Object} options - SMS scheduling options
 * @param {string} options.to - Phone number to send to
 * @param {string} options.message - SMS message content
 * @param {Date} options.scheduledTime - When to send the SMS
 * @param {Object} options.metadata - Additional metadata
 * @returns {Promise<Object>} Scheduled SMS result
 */
const scheduleSMS = async (options) => {
  try {
    const { to, message, scheduledTime, metadata = {} } = options;

    if (!to || !message || !scheduledTime) {
      throw new Error('Phone number, message, and scheduled time are required');
    }

    // Validate scheduled time is in the future
    if (new Date(scheduledTime) <= new Date()) {
      throw new Error('Scheduled time must be in the future');
    }

    // Clean and validate phone number
    const cleanedPhone = cleanPhoneNumber(to);
    if (!isValidPhoneNumber(cleanedPhone)) {
      throw new Error(`Invalid phone number format: ${to}`);
    }

    // Create scheduled SMS entry
    const scheduledSMS = {
      to: cleanedPhone,
      message,
      scheduledTime: new Date(scheduledTime),
      status: 'pending',
      metadata,
      createdAt: new Date()
    };

    // Save to database
    await saveScheduledSMS(scheduledSMS);

    return {
      success: true,
      data: scheduledSMS,
      message: 'SMS scheduled successfully'
    };
  } catch (error) {
    console.error('SMS scheduling error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to schedule SMS',
        code: 'SMS_SCHEDULE_FAILED',
        details: error.message
      }
    };
  }
};

/**
 * Get SMS status by SID
 * @param {string} sid - Twilio message SID
 * @returns {Promise<Object>} SMS status
 */
const getSMSStatus = async (sid) => {
  try {
    const message = await client.messages(sid).fetch();
    
    return {
      success: true,
      data: {
        sid: message.sid,
        status: message.status,
        direction: message.direction,
        from: message.from,
        to: message.to,
        body: message.body,
        dateCreated: message.dateCreated,
        dateUpdated: message.dateUpdated,
        errorCode: message.errorCode,
        errorMessage: message.errorMessage
      }
    };
  } catch (error) {
    console.error('SMS status check error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to get SMS status',
        code: 'SMS_STATUS_CHECK_FAILED',
        details: error.message
      }
    };
  }
};

/**
 * Cancel scheduled SMS
 * @param {string} scheduledSMSId - Scheduled SMS ID
 * @returns {Promise<Object>} Cancellation result
 */
const cancelScheduledSMS = async (scheduledSMSId) => {
  try {
    // Find scheduled SMS
    const scheduledSMS = await findScheduledSMS(scheduledSMSId);
    
    if (!scheduledSMS) {
      throw new Error('Scheduled SMS not found');
    }

    if (scheduledSMS.status === 'sent') {
      throw new Error('SMS has already been sent');
    }

    // Update status to cancelled
    await updateScheduledSMS(scheduledSMSId, {
      status: 'cancelled',
      cancelledAt: new Date()
    });

    return {
      success: true,
      data: {
        id: scheduledSMSId,
        status: 'cancelled',
        cancelledAt: new Date()
      },
      message: 'Scheduled SMS cancelled successfully'
    };
  } catch (error) {
    console.error('SMS cancellation error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to cancel scheduled SMS',
        code: 'SMS_CANCEL_FAILED',
        details: error.message
      }
    };
  }
};

/**
 * Send bulk SMS to multiple recipients
 * @param {Object} options - Bulk SMS options
 * @param {Array<string>} options.to - Array of phone numbers
 * @param {string} options.message - SMS message content
 * @param {Object} options.metadata - Additional metadata
 * @returns {Promise<Object>} Bulk SMS result
 */
const sendBulkSMS = async (options) => {
  try {
    const { to, message, metadata = {} } = options;

    if (!to || !Array.isArray(to) || to.length === 0) {
      throw new Error('Recipients array is required');
    }

    if (!message) {
      throw new Error('Message content is required');
    }

    const results = [];
    const failures = [];

    // Send SMS to each recipient
    for (const phoneNumber of to) {
      const smsResult = await sendSMS({
        to: phoneNumber,
        message,
        metadata: {
          ...metadata,
          bulkId: Date.now(),
          recipientIndex: results.length
        }
      });

      if (smsResult.success) {
        results.push({
          to: phoneNumber,
          sid: smsResult.data.sid,
          status: smsResult.data.status
        });
      } else {
        failures.push({
          to: phoneNumber,
          error: smsResult.error.message
        });
      }
    }

    return {
      success: true,
      data: {
        totalSent: results.length,
        totalFailed: failures.length,
        results,
        failures
      },
      metadata: {
        sentAt: new Date(),
        messageLength: message.length
      }
    };
  } catch (error) {
    console.error('Bulk SMS error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to send bulk SMS',
        code: 'BULK_SMS_FAILED',
        details: error.message
      }
    };
  }
};

/**
 * Send visit confirmation SMS
 * @param {Object} options - Visit options
 * @param {string} options.leadName - Lead's name
 * @param {string} options.propertyAddress - Property address
 * @param {Date} options.visitDate - Visit date and time
 * @param {string} options.locationLink - Google Maps link
 * @param {string} options.contactPhone - Contact phone number
 * @param {string} options.leaderPhone - Leader phone number
 * @returns {Promise<Object>} SMS result
 */
const sendVisitConfirmationSMS = async (options) => {
  try {
    const { leadName, leadPhone, propertyAddress, visitDate, locationLink, contactPhone, leaderPhone } = options;

    // Format visit date in French (for Quebec)
    const formattedDate = formatVisitDate(visitDate);

    // Generate personalized SMS content
    const message = generateVisitConfirmationMessage({
      leadName,
      propertyAddress,
      formattedDate,
      locationLink,
      contactPhone,
      leaderPhone
    });

    // Send SMS to lead
    const smsResult = await sendSMS({
      to: leadPhone,
      message,
      metadata: {
        type: 'visit_confirmation',
        visitDate: visitDate.toISOString(),
        propertyAddress,
        purpose: 'confirm_visit'
      }
    });

    // Also send SMS reminder to team member
    if (contactPhone) {
      await sendSMS({
        to: contactPhone,
        message: generateTeamReminderMessage({
          leadName,
          propertyAddress,
          formattedDate,
          locationLink
        }),
        metadata: {
          type: 'team_reminder',
          visitDate: visitDate.toISOString(),
          propertyAddress,
          purpose: 'team_reminder'
        }
      });
    }

    return smsResult;
  } catch (error) {
    console.error('Visit confirmation SMS error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to send visit confirmation SMS',
        code: 'VISIT_CONFIRMATION_SMS_FAILED',
        details: error.message
      }
    };
  }
};

/**
 * Send visit reminder SMS
 * @param {Object} options - Visit options
 * @param {string} options.leadName - Lead's name
 * @param {string} options.propertyAddress - Property address
 * @param {Date} options.visitDate - Visit date and time
 * @param {string} options.locationLink - Google Maps link
 * @param {string} options.contactPhone - Contact phone number
 * @returns {Promise<Object>} SMS result
 */
const sendVisitReminderSMS = async (options) => {
  try {
    const { leadName, propertyAddress, visitDate, locationLink, contactPhone } = options;

    // Format visit date in French
    const formattedDate = formatVisitDate(visitDate);

    // Generate reminder message
    const message = generateVisitReminderMessage({
      leadName,
      propertyAddress,
      formattedDate,
      locationLink
    });

    // Send SMS to lead
    const smsResult = await sendSMS({
      to: contactPhone,
      message,
      metadata: {
        type: 'visit_reminder',
        visitDate: visitDate.toISOString(),
        propertyAddress,
        purpose: 'visit_reminder'
      }
    });

    return smsResult;
  } catch (error) {
    console.error('Visit reminder SMS error:', error);
    return {
      success: false,
      error: {
        message: 'Failed to send visit reminder SMS',
        code: 'VISIT_REMINDER_SMS_FAILED',
        details: error.message
      }
    };
  }
};

// Helper functions

const cleanPhoneNumber = (phone) => {
  return phone.replace(/[\s\-\(\)]/g, '');
};

const isValidPhoneNumber = (phone) => {
  // Basic validation - should be 10 digits for North American numbers
  const phoneRegex = /^\d{10}$/;
  return phoneRegex.test(phone) || phone.startsWith('+1') && phone.length === 12;
};

const formatVisitDate = (date) => {
  const visitDate = new Date(date);
  const options = {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  };
  return visitDate.toLocaleDateString('fr-CA', options);
};

const generateVisitConfirmationMessage = (options) => {
  const { leadName, propertyAddress, formattedDate, locationLink, contactPhone } = options;
  return `Bonjour ${leadName} ! Votre visite à l'adresse ${propertyAddress} est confirmée pour le ${formattedDate}. ${locationLink ? 'Lien vers la localisation: ' + locationLink : ''} Numéro de contact: ${contactPhone}. Immogestion.`;
};

const generateVisitReminderMessage = (options) => {
  const { leadName, propertyAddress, formattedDate, locationLink } = options;
  return `Rappel: Votre visite à l'adresse ${propertyAddress} est prévue pour le ${formattedDate}. ${locationLink ? 'Lien vers la localisation: ' + locationLink : ''} Immogestion.`;
};

const generateTeamReminderMessage = (options) => {
  const { leadName, propertyAddress, formattedDate, locationLink } = options;
  return `Rappel d'équipe: Visite avec ${leadName} à ${propertyAddress} le ${formattedDate}. ${locationLink ? 'Lien vers la localisation: ' + locationLink : ''}. Immogestion.`;
};

// Database functions (placeholder implementations)
const saveSMSLog = async (smsLog) => {
  // Implement database save logic
  console.log('Saving SMS log:', smsLog);
};

const saveScheduledSMS = async (scheduledSMS) => {
  // Implement database save logic
  console.log('Saving scheduled SMS:', scheduledSMS);
};

const findScheduledSMS = async (scheduledSMSId) => {
  // Implement database find logic
  console.log('Finding scheduled SMS:', scheduledSMSId);
  return null;
};

const updateScheduledSMS = async (scheduledSMSId, updates) => {
  // Implement database update logic
  console.log('Updating scheduled SMS:', scheduledSMSId, updates);
};

module.exports = {
  sendSMS,
  scheduleSMS,
  getSMSStatus,
  cancelScheduledSMS,
  sendBulkSMS,
  sendVisitConfirmationSMS,
  sendVisitReminderSMS
};