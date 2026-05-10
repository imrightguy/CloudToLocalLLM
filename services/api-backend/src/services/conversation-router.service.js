const { eq, and, desc, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  communicationLogsTable,
  communicationThreadsTable,
  leadsTable,
} = require('../database/schema');
const {
  normalizeCommunicationAttachments,
  normalizeCommunicationMetadata,
  normalizeCommunicationStatus,
  normalizeCommunicationText,
} = require('../utils/communication');
const logger = require('../utils/logger');

const CHANNEL_TYPES = {
  SMS: 'sms',
  WHATSAPP: 'whatsapp',
  FB_MESSENGER: 'fb_messenger',
  EMAIL: 'email',
  PHONE: 'phone',
};

const DIRECTIONS = {
  INBOUND: 'inbound',
  OUTBOUND: 'outbound',
};

async function logCrossChannelMessage({
  leadId,
  employeeId = null,
  channel,
  direction,
  content,
  status = 'sent',
  attachments = [],
  metadata = {},
}) {
  if (!leadId) {
    logger.warn('[ConversationRouter] logCrossChannelMessage called without leadId');
    return null;
  }

  if (!Object.values(CHANNEL_TYPES).includes(channel)) {
    logger.warn(`[ConversationRouter] Unknown channel type: ${channel}`);
    return null;
  }

  try {
    const insertQuery = db.insert(communicationLogsTable).values({
      leadId,
      employeeId: employeeId || null,
      type: channel,
      direction: direction || DIRECTIONS.OUTBOUND,
      content: normalizeCommunicationText(content),
      attachments: normalizeCommunicationAttachments(attachments),
      status: normalizeCommunicationStatus(status),
      metadata: normalizeCommunicationMetadata({
        ...metadata,
        channel,
      }),
    });

    const insertedRows = typeof insertQuery.returning === 'function'
      ? await insertQuery.returning({ id: sql`id` })
      : await insertQuery;

    const logId = insertedRows?.[0]?.id || null;

    await updateThreadOnMessage(leadId, {
      channel,
      direction,
      content,
    });

    return logId;
  } catch (err) {
    logger.error('[ConversationRouter] Failed to log cross-channel message:', err.message);
    return null;
  }
}

async function updateThreadOnMessage(leadId, { channel, direction, content }) {
  try {
    const [existing] = await db
      .select()
      .from(communicationThreadsTable)
      .where(eq(communicationThreadsTable.leadId, leadId))
      .limit(1);

    if (existing) {
      await db
        .update(communicationThreadsTable)
        .set({
          messageCount: (existing.messageCount || 0) + 1,
          lastMessageAt: new Date(),
          lastMessageType: channel,
          lastMessageDirection: direction,
          updatedAt: new Date(),
        })
        .where(eq(communicationThreadsTable.id, existing.id));
    }
  } catch (err) {
    logger.error('[ConversationRouter] Failed to update thread on message:', err.message);
  }
}

async function getLeadConversationTimeline(leadId, { limit = 50, offset = 0 } = {}) {
  if (!leadId) return [];

  try {
    const messages = await db
      .select()
      .from(communicationLogsTable)
      .where(eq(communicationLogsTable.leadId, leadId))
      .orderBy(desc(communicationLogsTable.createdAt))
      .limit(limit)
      .offset(offset);

    return messages;
  } catch (err) {
    logger.error('[ConversationRouter] Failed to get conversation timeline:', err.message);
    return [];
  }
}

async function getMessagesByChannel(leadId, channel, { limit = 50 } = {}) {
  if (!leadId || !channel) return [];

  try {
    const messages = await db
      .select()
      .from(communicationLogsTable)
      .where(and(
        eq(communicationLogsTable.leadId, leadId),
        eq(communicationLogsTable.type, channel),
      ))
      .orderBy(desc(communicationLogsTable.createdAt))
      .limit(limit);

    return messages;
  } catch (err) {
    logger.error('[ConversationRouter] Failed to get messages by channel:', err.message);
    return [];
  }
}

async function findLeadByPhone(phoneNumber) {
  if (!phoneNumber) return null;

  const cleaned = phoneNumber.replace(/[\s\-()]/g, '').replace(/^whatsapp:/, '');

  try {
    const [lead] = await db
      .select({
        id: leadsTable.id,
        fullName: leadsTable.fullName,
        phone: leadsTable.phone,
        email: leadsTable.email,
        source: leadsTable.source,
        stage: leadsTable.stage,
      })
      .from(leadsTable)
      .where(eq(leadsTable.phone, cleaned))
      .limit(1);

    return lead || null;
  } catch (err) {
    logger.error('[ConversationRouter] Failed to find lead by phone:', err.message);
    return null;
  }
}

async function getPreferredChannel(leadId) {
  if (!leadId) return null;

  try {
    const [row] = await db
      .select({
        type: communicationLogsTable.type,
        count: sql`count(*)`.as('count'),
      })
      .from(communicationLogsTable)
      .where(eq(communicationLogsTable.leadId, leadId))
      .groupBy(communicationLogsTable.type)
      .orderBy(desc(sql`count(*)`))
      .limit(1);

    return row?.type || null;
  } catch (err) {
    logger.error('[ConversationRouter] Failed to get preferred channel:', err.message);
    return null;
  }
}

module.exports = {
  CHANNEL_TYPES,
  DIRECTIONS,
  logCrossChannelMessage,
  updateThreadOnMessage,
  getLeadConversationTimeline,
  getMessagesByChannel,
  findLeadByPhone,
  getPreferredChannel,
};
