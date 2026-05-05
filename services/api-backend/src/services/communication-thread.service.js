const {
  eq, and, desc, ilike, or, inArray,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  communicationLogsTable,
  communicationThreadsTable,
  leadsTable,
  visitsTable,
} = require('../database/schema');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');
const { BOOKING_STATES, QUALIFICATION_STATES } = require('../constants/marketplace-states');
const logger = require('../utils/logger');

const log = typeof logger.child === 'function'
  ? logger.child({ service: 'communication-thread' })
  : {
    error: () => {},
    warn: () => {},
    info: () => {},
    debug: () => {},
  };

const THREAD_STATE_RANK = {
  message_only: 0,
  awaiting_tenant_confirmation: 1,
  awaiting_employee_confirmation: 2,
  scheduled: 3,
  confirmed: 4,
  in_progress: 5,
  follow_up_required: 6,
  completed_no_show: 7,
  completed_interested: 8,
  completed_not_interested: 9,
  cancelled: 10,
};

const LEAD_STAGE_RANK = new Map(VALID_LEAD_STAGES.map((stage, index) => [stage, index]));

function parsePositiveInt(value, fallback, min, max) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, parsed));
}

function parseBoolean(value, fallback = true) {
  if (value === undefined) {
    return fallback;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  return String(value).toLowerCase() !== 'false';
}

function getInitials(name) {
  const parts = String(name || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (parts.length === 0) {
    return '??';
  }
  return parts.slice(0, 2).map((part) => part[0].toUpperCase()).join('');
}

function toDateOrNull(value) {
  if (!value) {
    return null;
  }

  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function calculateFirstResponseMetrics(messages = []) {
  const orderedMessages = [...messages]
    .filter((message) => message && message.createdAt)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));

  const firstInboundMessage = orderedMessages.find((message) => message.direction === 'inbound') || null;
  if (!firstInboundMessage) {
    return {
      firstSeenAt: null,
      firstResponseAt: null,
      firstResponseDelayMinutes: null,
    };
  }

  const firstSeenAt = firstInboundMessage.createdAt;
  const firstResponseMessage = orderedMessages.find(
    (message) => message.direction === 'outbound' && new Date(message.createdAt) > new Date(firstSeenAt),
  ) || null;

  if (!firstResponseMessage) {
    return {
      firstSeenAt,
      firstResponseAt: null,
      firstResponseDelayMinutes: null,
    };
  }

  const firstSeenDate = toDateOrNull(firstSeenAt);
  const firstResponseDate = toDateOrNull(firstResponseMessage.createdAt);
  const firstResponseDelayMinutes = firstSeenDate && firstResponseDate
    ? Math.round((firstResponseDate.getTime() - firstSeenDate.getTime()) / 60000)
    : null;

  return {
    firstSeenAt,
    firstResponseAt: firstResponseMessage.createdAt,
    firstResponseDelayMinutes,
  };
}

function serializeCommunication(row) {
  if (!row) {
    return null;
  }

  return {
    ...row,
    updatedAt: row.updatedAt ?? row.createdAt,
  };
}

function serializeVisit(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    unitId: row.unitId,
    employeeId: row.employeeId,
    leadId: row.leadId,
    dateTime: row.dateTime,
    durationMinutes: row.durationMinutes,
    status: row.status,
    tenantConfirmed: row.tenantConfirmed,
    employeeConfirmed: row.employeeConfirmed,
    morningOfSent: row.morningOfSent,
    outcome: row.outcome,
    reasonCode: row.reasonCode,
    completedAt: row.completedAt,
    cancelledAt: row.cancelledAt,
    noShowAt: row.noShowAt,
    rescheduledAt: row.rescheduledAt,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt ?? row.createdAt,
  };
}

function deriveVisitThreadState(visit) {
  if (!visit) {
    return null;
  }

  if (visit.status === 'cancelled') {
    return 'cancelled';
  }

  if (visit.status === 'completed') {
    if (visit.outcome === 'interesse') {
      return 'completed_interested';
    }

    if (visit.outcome === 'pas_interesse') {
      return 'completed_not_interested';
    }

    if (visit.outcome === 'no_show') {
      return 'completed_no_show';
    }

    return 'follow_up_required';
  }

  if (visit.status === 'no_show') {
    return 'completed_no_show';
  }

  if (visit.status === 'in_progress') {
    return 'in_progress';
  }

  if (visit.status === 'confirmed' || (visit.tenantConfirmed && visit.employeeConfirmed)) {
    return 'confirmed';
  }

  if (visit.tenantConfirmed && !visit.employeeConfirmed) {
    return 'awaiting_employee_confirmation';
  }

  if (visit.employeeConfirmed && !visit.tenantConfirmed) {
    return 'awaiting_tenant_confirmation';
  }

  if (visit.status === 'scheduled') {
    return 'awaiting_tenant_confirmation';
  }

  return 'scheduled';
}

function deriveThreadState({ threadState, leadStage, latestVisit }) {
  const visitState = deriveVisitThreadState(latestVisit);
  if (visitState) {
    return visitState;
  }

  if (threadState && Object.prototype.hasOwnProperty.call(THREAD_STATE_RANK, threadState)) {
    return threadState;
  }

  if (leadStage === 'visitePlanifiee' || leadStage === 'visite_planifiee') {
    return 'scheduled';
  }

  if (leadStage === 'visite_completee') {
    return 'follow_up_required';
  }

  return 'message_only';
}

function compareThreadSnapshots(a, b) {
  const responseNeededA = a.firstResponseAt ? 1 : 0;
  const responseNeededB = b.firstResponseAt ? 1 : 0;
  if (responseNeededA !== responseNeededB) {
    return responseNeededA - responseNeededB;
  }

  const stateA = THREAD_STATE_RANK[a.coordinationState] ?? 999;
  const stateB = THREAD_STATE_RANK[b.coordinationState] ?? 999;
  if (stateA !== stateB) {
    return stateA - stateB;
  }

  const inboundA = a._lastInboundAt ? new Date(a._lastInboundAt).getTime() : Number.POSITIVE_INFINITY;
  const inboundB = b._lastInboundAt ? new Date(b._lastInboundAt).getTime() : Number.POSITIVE_INFINITY;
  if (inboundA !== inboundB) {
    return inboundA - inboundB;
  }

  const visitA = a._upcomingVisitAt ? new Date(a._upcomingVisitAt).getTime() : Number.POSITIVE_INFINITY;
  const visitB = b._upcomingVisitAt ? new Date(b._upcomingVisitAt).getTime() : Number.POSITIVE_INFINITY;
  if (visitA !== visitB) {
    return visitA - visitB;
  }

  const activityA = a._lastActivityAt ? new Date(a._lastActivityAt).getTime() : 0;
  const activityB = b._lastActivityAt ? new Date(b._lastActivityAt).getTime() : 0;
  return activityB - activityA;
}

function cleanSnapshot(snapshot, includeMessages) {
  const {
    _lastInboundAt,
    _lastActivityAt,
    _upcomingVisitAt,
    ...rest
  } = snapshot;

  if (!includeMessages) {
    delete rest.messages;
  }

  return rest;
}

function buildSnapshot(lead, threadRow, messages, visits, includeMessages) {
  const orderedMessages = [...messages].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  const orderedVisits = [...visits].sort((a, b) => new Date(b.dateTime) - new Date(a.dateTime));
  const latestMessage = orderedMessages[0] || null;
  const latestVisit = orderedVisits[0] || null;
  const firstResponseMetrics = calculateFirstResponseMetrics(messages);

  if (!latestMessage && !latestVisit) {
    return null;
  }

  const lastInboundMessage = orderedMessages.find((message) => message.direction === 'inbound') || null;
  const lastActivityAt = latestMessage?.createdAt
    || latestVisit?.dateTime
    || threadRow?.lastMessageAt
    || lead.updatedAt
    || lead.createdAt
    || null;

  const snapshot = {
    leadId: lead.id,
    contactId: lead.id,
    contactName: lead.fullName,
    contactPhone: lead.phone,
    contactInitials: getInitials(lead.fullName),
    messageCount: threadRow?.messageCount ?? orderedMessages.length,
    lastMessageAt: latestMessage?.createdAt ?? threadRow?.lastMessageAt ?? null,
    firstSeenAt: firstResponseMetrics.firstSeenAt,
    firstResponseAt: firstResponseMetrics.firstResponseAt,
    firstResponseDelayMinutes: firstResponseMetrics.firstResponseDelayMinutes,
    coordinationState: deriveThreadState({
      threadState: threadRow?.coordinationState,
      leadStage: lead.stage,
      latestVisit,
    }),
    latestVisit: latestVisit ? serializeVisit(latestVisit) : null,
    lastMessage: latestMessage ? serializeCommunication(latestMessage) : null,
    messages: includeMessages ? orderedMessages.map(serializeCommunication) : undefined,
    _lastInboundAt: lastInboundMessage?.createdAt ?? null,
    _lastActivityAt: lastActivityAt,
    _upcomingVisitAt: latestVisit?.dateTime ?? null,
  };

  return cleanSnapshot(snapshot, includeMessages);
}

function buildLeadConditions(filters = {}) {
  const conditions = [eq(leadsTable.isActive, true)];

  if (filters.leadId) {
    conditions.push(eq(leadsTable.id, filters.leadId));
  }

  if (filters.stage) {
    conditions.push(eq(leadsTable.stage, filters.stage));
  }

  if (filters.source) {
    conditions.push(eq(leadsTable.source, filters.source));
  }

  if (filters.assignedEmployeeId) {
    conditions.push(eq(leadsTable.assignedEmployeeId, filters.assignedEmployeeId));
  }

  if (filters.search) {
    const query = `%${filters.search}%`;
    conditions.push(or(
      ilike(leadsTable.fullName, query),
      ilike(leadsTable.phone, query),
      ilike(leadsTable.email, query),
      ilike(leadsTable.source, query),
      ilike(leadsTable.stage, query),
      ilike(leadsTable.desiredUnit, query),
      ilike(leadsTable.notes, query),
    ));
  }

  return conditions;
}

async function loadThreadContext(filters = {}) {
  const page = parsePositiveInt(filters.page, 1, 1, 1000000);
  const limit = parsePositiveInt(filters.limit, 20, 1, 100);
  const includeMessages = parseBoolean(filters.includeMessages, true);

  const leadConditions = buildLeadConditions(filters);
  const leadWhere = and(...leadConditions);

  const leads = await db
    .select({
      id: leadsTable.id,
      fullName: leadsTable.fullName,
      phone: leadsTable.phone,
      email: leadsTable.email,
      stage: leadsTable.stage,
      source: leadsTable.source,
      desiredUnit: leadsTable.desiredUnit,
      assignedEmployeeId: leadsTable.assignedEmployeeId,
      notes: leadsTable.notes,
      createdAt: leadsTable.createdAt,
      updatedAt: leadsTable.updatedAt,
    })
    .from(leadsTable)
    .where(leadWhere)
    .orderBy(desc(leadsTable.updatedAt));

  if (leads.length === 0) {
    return {
      threads: [],
      pagination: {
        total: 0,
        page,
        limit,
        totalPages: 0,
        hasMore: false,
      },
    };
  }

  const leadIds = leads.map((lead) => lead.id);
  const messageConditions = [
    eq(communicationLogsTable.isActive, true),
    inArray(communicationLogsTable.leadId, leadIds),
  ];

  if (filters.type) {
    messageConditions.push(eq(communicationLogsTable.type, filters.type));
  }
  if (filters.direction) {
    messageConditions.push(eq(communicationLogsTable.direction, filters.direction));
  }
  if (filters.status) {
    messageConditions.push(eq(communicationLogsTable.status, filters.status));
  }

  const [messages, visits, threadRows] = await Promise.all([
    db
      .select({
        id: communicationLogsTable.id,
        leadId: communicationLogsTable.leadId,
        employeeId: communicationLogsTable.employeeId,
        type: communicationLogsTable.type,
        direction: communicationLogsTable.direction,
        subject: communicationLogsTable.subject,
        content: communicationLogsTable.content,
        attachments: communicationLogsTable.attachments,
        status: communicationLogsTable.status,
        metadata: communicationLogsTable.metadata,
        createdAt: communicationLogsTable.createdAt,
      })
      .from(communicationLogsTable)
      .where(and(...messageConditions))
      .orderBy(desc(communicationLogsTable.createdAt)),
    db
      .select({
        id: visitsTable.id,
        leadId: visitsTable.leadId,
        unitId: visitsTable.unitId,
        employeeId: visitsTable.employeeId,
        dateTime: visitsTable.dateTime,
        durationMinutes: visitsTable.durationMinutes,
        status: visitsTable.status,
        tenantConfirmed: visitsTable.tenantConfirmed,
        employeeConfirmed: visitsTable.employeeConfirmed,
        morningOfSent: visitsTable.morningOfSent,
        outcome: visitsTable.outcome,
        reasonCode: visitsTable.reasonCode,
        completedAt: visitsTable.completedAt,
        cancelledAt: visitsTable.cancelledAt,
        noShowAt: visitsTable.noShowAt,
        rescheduledAt: visitsTable.rescheduledAt,
        notes: visitsTable.notes,
        createdAt: visitsTable.createdAt,
        updatedAt: visitsTable.updatedAt,
      })
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        inArray(visitsTable.leadId, leadIds),
      ))
      .orderBy(desc(visitsTable.dateTime)),
    db
      .select({
        leadId: communicationThreadsTable.leadId,
        coordinationState: communicationThreadsTable.coordinationState,
        messageCount: communicationThreadsTable.messageCount,
        lastMessageAt: communicationThreadsTable.lastMessageAt,
        lastMessageType: communicationThreadsTable.lastMessageType,
        lastMessageDirection: communicationThreadsTable.lastMessageDirection,
        latestVisitId: communicationThreadsTable.latestVisitId,
      })
      .from(communicationThreadsTable)
      .where(inArray(communicationThreadsTable.leadId, leadIds)),
  ]);

  const messagesByLeadId = new Map();
  for (const message of messages) {
    const list = messagesByLeadId.get(message.leadId) || [];
    list.push(message);
    messagesByLeadId.set(message.leadId, list);
  }

  const visitsByLeadId = new Map();
  for (const visit of visits) {
    const list = visitsByLeadId.get(visit.leadId) || [];
    list.push(visit);
    visitsByLeadId.set(visit.leadId, list);
  }

  const threadByLeadId = new Map();
  for (const threadRow of threadRows) {
    threadByLeadId.set(threadRow.leadId, threadRow);
  }

  const snapshots = leads
    .map((lead) => buildSnapshot(
      lead,
      threadByLeadId.get(lead.id) || null,
      messagesByLeadId.get(lead.id) || [],
      visitsByLeadId.get(lead.id) || [],
      includeMessages,
    ))
    .filter(Boolean);

  const filteredSnapshots = snapshots.filter((snapshot) => {
    if (!filters.type && !filters.direction && !filters.status) {
      return true;
    }

    const latest = snapshot.lastMessage;
    if (!latest) {
      return false;
    }

    if (filters.type && latest.type !== filters.type) {
      return false;
    }

    if (filters.direction && latest.direction !== filters.direction) {
      return false;
    }

    if (filters.status && latest.status !== filters.status) {
      return false;
    }

    return true;
  });

  filteredSnapshots.sort(compareThreadSnapshots);

  const total = filteredSnapshots.length;
  const totalPages = Math.ceil(total / limit);
  const offset = (page - 1) * limit;
  const pagedThreads = filteredSnapshots.slice(offset, offset + limit);

  return {
    threads: pagedThreads,
    pagination: {
      total,
      page,
      limit,
      totalPages,
      hasMore: page < totalPages,
    },
  };
}

async function refreshCommunicationThread(leadId, options = {}) {
  if (!leadId) {
    return null;
  }

  const includeMessages = parseBoolean(options.includeMessages, false);
  const { threads } = await loadThreadContext({
    leadId,
    includeMessages,
    page: 1,
    limit: 1,
  });

  const thread = threads[0] || null;
  if (!thread) {
    const [existing] = await db
      .select({ id: communicationThreadsTable.id })
      .from(communicationThreadsTable)
      .where(eq(communicationThreadsTable.leadId, leadId))
      .limit(1);

    if (!existing) {
      return null;
    }

    try {
      await db
        .update(communicationThreadsTable)
        .set({
          latestVisitId: null,
          coordinationState: 'message_only',
          messageCount: 0,
          lastMessageAt: null,
          lastMessageType: null,
          lastMessageDirection: null,
          updatedAt: new Date(),
        })
        .where(eq(communicationThreadsTable.leadId, leadId));
    } catch (error) {
      log.warn('Failed to reset communication thread', { leadId, error: error.message });
    }

    return null;
  }

  const latestVisitId = thread.latestVisit?.id ?? null;
  const lastMessage = thread.lastMessage;
  const updateData = {
    latestVisitId,
    coordinationState: thread.coordinationState,
    messageCount: thread.messageCount,
    lastMessageAt: thread.lastMessageAt ? new Date(thread.lastMessageAt) : null,
    lastMessageType: lastMessage?.type ?? null,
    lastMessageDirection: lastMessage?.direction ?? null,
    updatedAt: new Date(),
  };

  const [existing] = await db
    .select({ id: communicationThreadsTable.id })
    .from(communicationThreadsTable)
    .where(eq(communicationThreadsTable.leadId, leadId))
    .limit(1);

  try {
    if (existing) {
      await db
        .update(communicationThreadsTable)
        .set(updateData)
        .where(eq(communicationThreadsTable.leadId, leadId));
    } else {
      await db.insert(communicationThreadsTable).values({
        leadId,
        ...updateData,
        isActive: true,
      });
    }
  } catch (error) {
    log.warn('Failed to refresh communication thread', { leadId, error: error.message });
  }

  return thread;
}

async function getConversationThreads(filters = {}) {
  return loadThreadContext(filters);
}

async function getLeadTimeline(leadId, filters = {}) {
  const result = await loadThreadContext({
    ...filters,
    leadId,
    page: 1,
    limit: 1,
    includeMessages: parseBoolean(filters.includeMessages, true),
  });

  return result.threads[0] || null;
}

async function recordCommunicationActivity(payload = {}) {
  const leadId = payload.leadId || null;
  const employeeId = payload.employeeId || null;
  const type = payload.type;
  const direction = payload.direction;
  const subject = payload.subject?.trim() || null;
  const content = payload.content?.trim() || payload.body?.trim() || null;
  const attachments = payload.attachments || [];
  const status = payload.status?.trim() || 'sent';
  const metadata = payload.metadata || {};

  if (!type || !direction) {
    return {
      statusCode: 400,
      body: {
        success: false,
        error: { message: 'type and direction are required', code: 'VALIDATION_ERROR' },
      },
    };
  }

  try {
    const insertValues = {
      leadId,
      type,
      direction,
      status,
      isActive: true,
    };

    if (employeeId) { insertValues.employeeId = employeeId; }
    if (content) { insertValues.content = content; }
    if (subject) { insertValues.subject = subject; }
    if (Array.isArray(attachments) && attachments.length > 0) { insertValues.attachments = attachments; }
    if (metadata && typeof metadata === 'object' && !Array.isArray(metadata) && Object.keys(metadata).length > 0) {
      insertValues.metadata = metadata;
    }

    const [record] = await db.insert(communicationLogsTable).values(insertValues).returning();

    if (leadId) {
      try {
        const [lead] = await db
          .select({ id: leadsTable.id, stage: leadsTable.stage })
          .from(leadsTable)
          .where(eq(leadsTable.id, leadId))
          .limit(1);

        if (lead?.stage === 'nouveau' && direction === 'inbound') {
          await db
            .update(leadsTable)
            .set({ stage: 'contacte', updatedAt: new Date() })
            .where(eq(leadsTable.id, leadId));
        }
      } catch (stageError) {
        log.warn('Failed to advance lead stage after communication', { leadId, error: stageError.message });
      }

      await refreshCommunicationThread(leadId, { includeMessages: false });
    }

    return {
      statusCode: 201,
      body: {
        success: true,
        data: serializeCommunication(record),
        message: 'Communication logged successfully',
      },
    };
  } catch (error) {
    log.error('Failed to log communication', { error: error.message });

    if (error.code === '23503') {
      return {
        statusCode: 400,
        body: {
          success: false,
          error: { message: 'Invalid leadId or employeeId', code: 'FOREIGN_KEY_ERROR' },
        },
      };
    }

    return {
      statusCode: 500,
      body: {
        success: false,
        error: { message: 'Internal server error', code: 'COMMUNICATION_LOG_FAILED' },
      },
    };
  }
}

async function recordMarketplaceVisit(leadId, payload = {}) {
  if (!leadId) {
    return {
      statusCode: 400,
      body: {
        success: false,
        error: { message: 'leadId is required', code: 'VALIDATION_ERROR' },
      },
    };
  }

  const { createVisit } = require('../controllers/visit.controller');
  const req = {
    body: {
      ...payload,
      leadId,
    },
  };

  let statusCode = 200;
  let body = null;
  const res = {
    status(code) {
      statusCode = code;
      return this;
    },
    json(payloadBody) {
      body = payloadBody;
      return this;
    },
  };

  await createVisit(req, res);

  if (statusCode < 400 && leadId) {
    try {
      const [lead] = await db
        .select({ id: leadsTable.id, stage: leadsTable.stage })
        .from(leadsTable)
        .where(eq(leadsTable.id, leadId))
        .limit(1);

      if (lead && LEAD_STAGE_RANK.get(lead.stage) < LEAD_STAGE_RANK.get('visitePlanifiee')) {
        await db
          .update(leadsTable)
          .set({ stage: 'visitePlanifiee', updatedAt: new Date() })
          .where(eq(leadsTable.id, leadId));
      }
    } catch (stageError) {
      log.warn('Failed to advance lead stage after visit scheduling', { leadId, error: stageError.message });
    }

    await refreshCommunicationThread(leadId, { includeMessages: false });
  }

  return {
    statusCode,
    body,
  };
}

module.exports = {
  calculateFirstResponseMetrics,
  refreshCommunicationThread,
  getConversationThreads,
  getLeadTimeline,
  recordCommunicationActivity,
  recordMarketplaceVisit,
};
