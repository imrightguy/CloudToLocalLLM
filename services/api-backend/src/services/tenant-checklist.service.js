const { and, asc, desc, eq } = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  tenantChecklistSessionsTable,
  tenantChecklistStepsTable,
  tenantChecklistAttachmentsTable,
  tenantChecklistSignaturesTable,
  tenantChecklistEventsTable,
  unitsTable,
  leasesTable,
} = require('../database/schema');
const {
  VALID_CHECKLIST_TYPES,
  VALID_SESSION_STATUSES,
  VALID_STEP_STATUSES,
  buildChecklistTemplate,
} = require('../models/tenant-checklist');

const IMMUTABLE_SESSION_STATUSES = ['completed', 'reviewed', 'archived'];

const now = () => new Date();

const toIso = (value) => {
  if (!value) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
};

const notFoundError = (code, message) => {
  const error = new Error(message);
  error.statusCode = 404;
  error.code = code;
  return error;
};

const conflictError = (code, message) => {
  const error = new Error(message);
  error.statusCode = 409;
  error.code = code;
  return error;
};

const normalizeChecklistType = (value) => {
  const normalized = String(value || '').trim();
  if (!VALID_CHECKLIST_TYPES.includes(normalized)) {
    throw conflictError('INVALID_CHECKLIST_TYPE', 'Type de checklist invalide');
  }
  return normalized;
};

const fetchOne = async (query) => {
  const [row] = await query.limit(1);
  return row || null;
};

const loadSessionGraph = async (sessionId, client = db) => {
  const session = await fetchOne(client.select().from(tenantChecklistSessionsTable).where(eq(tenantChecklistSessionsTable.id, sessionId)));
  if (!session) {
    return null;
  }

  const unit = await fetchOne(client.select().from(unitsTable).where(eq(unitsTable.id, session.unitId)));
  const lease = session.leaseId
    ? await fetchOne(client.select().from(leasesTable).where(eq(leasesTable.id, session.leaseId)))
    : null;
  const steps = await client.select().from(tenantChecklistStepsTable).where(eq(tenantChecklistStepsTable.sessionId, sessionId)).orderBy(asc(tenantChecklistStepsTable.stepOrder));
  const attachments = await client.select().from(tenantChecklistAttachmentsTable).where(eq(tenantChecklistAttachmentsTable.sessionId, sessionId)).orderBy(desc(tenantChecklistAttachmentsTable.createdAt));
  const signatures = await client.select().from(tenantChecklistSignaturesTable).where(eq(tenantChecklistSignaturesTable.sessionId, sessionId)).orderBy(asc(tenantChecklistSignaturesTable.signedAt));
  const events = await client.select().from(tenantChecklistEventsTable).where(eq(tenantChecklistEventsTable.sessionId, sessionId)).orderBy(desc(tenantChecklistEventsTable.createdAt));

  return {
    session,
    unit,
    lease,
    steps,
    attachments,
    signatures,
    events,
  };
};

const buildSummary = (graph) => {
  if (!graph) {
    return null;
  }

  const { session, unit, lease, steps, attachments, signatures, events } = graph;
  const completedSteps = steps.filter((step) => step.status === 'completed').length;
  const blockedSteps = steps.filter((step) => step.status === 'blocked').length;
  const pendingSteps = steps.filter((step) => step.status === 'pending').length;
  const skippedSteps = steps.filter((step) => step.status === 'skipped').length;
  const lastEvent = events[0] || null;

  return {
    session: {
      ...session,
      startedAt: toIso(session.startedAt),
      resumedAt: toIso(session.resumedAt),
      pausedAt: toIso(session.pausedAt),
      completedAt: toIso(session.completedAt),
      submittedAt: toIso(session.submittedAt),
      reviewedAt: toIso(session.reviewedAt),
      createdAt: toIso(session.createdAt),
      updatedAt: toIso(session.updatedAt),
    },
    unit,
    lease,
    steps,
    attachments,
    signatures,
    events,
    summary: {
      stepCount: steps.length,
      completedStepCount: completedSteps,
      blockedStepCount: blockedSteps,
      pendingStepCount: pendingSteps,
      skippedStepCount: skippedSteps,
      attachmentCount: attachments.length,
      signatureCount: signatures.length,
      eventCount: events.length,
      isComplete: session.state === 'completed',
      isPaused: session.state === 'paused',
      lastEventAt: lastEvent ? toIso(lastEvent.createdAt) : null,
      currentStepKey: session.currentStepKey || null,
      currentStepOrder: session.currentStepOrder ?? null,
    },
  };
};

const buildStepRows = (sessionId, checklistType) => buildChecklistTemplate(checklistType).map((step) => ({
  sessionId,
  stepKey: step.stepKey,
  stepOrder: step.stepOrder,
  title: step.title,
  description: step.description,
  status: step.status,
  requiredFields: step.requiredFields,
  metadata: step.metadata,
}));

const ensureUnitAndLease = async (tx, unitId, leaseId) => {
  const unit = await fetchOne(tx.select().from(unitsTable).where(eq(unitsTable.id, unitId)));
  if (!unit) {
    throw notFoundError('UNIT_NOT_FOUND', 'Unité introuvable');
  }

  if (!leaseId) {
    return { unit, lease: null };
  }

  const lease = await fetchOne(tx.select().from(leasesTable).where(eq(leasesTable.id, leaseId)));
  if (!lease) {
    throw notFoundError('LEASE_NOT_FOUND', 'Bail introuvable');
  }

  if (lease.unitId !== unitId) {
    throw conflictError('LEASE_UNIT_MISMATCH', 'Le bail doit être associé à la même unité que la session');
  }

  return { unit, lease };
};

const createChecklistEvent = async (tx, payload) => {
  await tx.insert(tenantChecklistEventsTable).values({
    sessionId: payload.sessionId,
    eventType: payload.eventType,
    actorType: payload.actorType || 'user',
    actorUserId: payload.actorUserId || null,
    fromState: payload.fromState || null,
    toState: payload.toState || null,
    stepId: payload.stepId || null,
    payload: payload.payload || {},
    createdAt: payload.createdAt || now(),
  });
};

const updateStepRows = async (tx, sessionId, stepUpdates = []) => {
  for (const update of stepUpdates) {
    const step = await fetchOne(tx.select().from(tenantChecklistStepsTable).where(and(
      eq(tenantChecklistStepsTable.sessionId, sessionId),
      eq(tenantChecklistStepsTable.stepKey, update.stepKey),
    )));

    if (!step) {
      throw notFoundError('CHECKLIST_STEP_NOT_FOUND', `Étape introuvable: ${update.stepKey}`);
    }

    const nextValues = {
      status: update.status,
      notes: update.notes || null,
      blockedReason: update.blockedReason || null,
      metadata: update.metadata || step.metadata || {},
      completedAt: update.status === 'completed' ? now() : step.completedAt,
      updatedAt: now(),
    };

    await tx.update(tenantChecklistStepsTable)
      .set(nextValues)
      .where(eq(tenantChecklistStepsTable.id, step.id));

    if (update.status === 'completed') {
      await createChecklistEvent(tx, {
        sessionId,
        eventType: 'step_completed',
        stepId: step.id,
        payload: { stepKey: update.stepKey, notes: update.notes || null },
      });
    }

    if (update.status === 'blocked') {
      await createChecklistEvent(tx, {
        sessionId,
        eventType: 'step_blocked',
        stepId: step.id,
        payload: { stepKey: update.stepKey, blockedReason: update.blockedReason || null },
      });
    }
  }
};

const createAttachments = async (tx, sessionId, attachments = []) => {
  if (!attachments.length) {
    return;
  }

  const steps = await tx.select().from(tenantChecklistStepsTable).where(eq(tenantChecklistStepsTable.sessionId, sessionId));
  const stepByKey = new Map(steps.map((step) => [step.stepKey, step]));

  for (const attachment of attachments) {
    const step = stepByKey.get(attachment.stepKey);
    if (!step) {
      throw notFoundError('CHECKLIST_STEP_NOT_FOUND', `Étape introuvable: ${attachment.stepKey}`);
    }

    await tx.insert(tenantChecklistAttachmentsTable).values({
      sessionId,
      stepId: step.id,
      documentRefId: attachment.documentRefId || null,
      fileName: attachment.fileName || null,
      mimeType: attachment.mimeType || null,
      url: attachment.url || null,
      caption: attachment.caption || null,
      takenAt: attachment.takenAt ? new Date(attachment.takenAt) : null,
      metadata: attachment.metadata || {},
      createdAt: now(),
      updatedAt: now(),
    });

    await createChecklistEvent(tx, {
      sessionId,
      eventType: 'attachment_added',
      stepId: step.id,
      payload: { stepKey: attachment.stepKey, documentRefId: attachment.documentRefId || null },
    });
  }
};

const createSignatures = async (tx, sessionId, signatures = []) => {
  for (const signature of signatures) {
    const [existing] = await tx.select().from(tenantChecklistSignaturesTable).where(and(
      eq(tenantChecklistSignaturesTable.sessionId, sessionId),
      eq(tenantChecklistSignaturesTable.signatureType, signature.signatureType),
    )).limit(1);

    const values = {
      sessionId,
      signatureType: signature.signatureType,
      signerName: signature.signerName || null,
      signerRole: signature.signerRole || null,
      method: signature.method || 'typed',
      status: 'captured',
      signatureData: signature.signatureData || {},
      signedAt: signature.signedAt ? new Date(signature.signedAt) : now(),
      signedByUserId: signature.signedByUserId || null,
      metadata: signature.metadata || {},
      updatedAt: now(),
    };

    if (existing) {
      await tx.update(tenantChecklistSignaturesTable).set(values).where(eq(tenantChecklistSignaturesTable.id, existing.id));
    } else {
      await tx.insert(tenantChecklistSignaturesTable).values({
        ...values,
        createdAt: now(),
      });
    }

    await createChecklistEvent(tx, {
      sessionId,
      eventType: 'signature_recorded',
      payload: { signatureType: signature.signatureType, method: signature.method || 'typed' },
    });
  }
};

const loadSessionOrThrow = async (sessionId, client = db) => {
  const graph = await loadSessionGraph(sessionId, client);
  if (!graph) {
    throw notFoundError('CHECKLIST_SESSION_NOT_FOUND', 'Session de checklist introuvable');
  }
  return graph;
};

const startChecklistSession = async ({
  unitId,
  leaseId = null,
  checklistType,
  tenantName = null,
  tenantPhone = null,
  metadata = {},
  createdByUserId = null,
}) => db.transaction(async (tx) => {
  const normalizedType = normalizeChecklistType(checklistType);
  const { unit, lease } = await ensureUnitAndLease(tx, unitId, leaseId || null);
  const createdAt = now();

  const [session] = await tx.insert(tenantChecklistSessionsTable).values({
    unitId,
    leaseId: lease ? lease.id : null,
    checklistType: normalizedType,
    state: 'in_progress',
    currentStepKey: buildChecklistTemplate(normalizedType)[0]?.stepKey || null,
    currentStepOrder: buildChecklistTemplate(normalizedType)[0]?.stepOrder || 0,
    tenantName: tenantName || unit.tenantName || null,
    tenantPhone: tenantPhone || unit.tenantPhone || null,
    startedByUserId: createdByUserId,
    resumedByUserId: createdByUserId,
    startedAt: createdAt,
    resumedAt: createdAt,
    metadata: metadata || {},
    createdAt,
    updatedAt: createdAt,
  }).returning();

  await tx.insert(tenantChecklistStepsTable).values(buildStepRows(session.id, normalizedType));
  await createChecklistEvent(tx, {
    sessionId: session.id,
    eventType: 'session_started',
    actorUserId: createdByUserId,
    fromState: 'draft',
    toState: 'in_progress',
    payload: { checklistType: normalizedType, unitId, leaseId: lease ? lease.id : null },
    createdAt,
  });

  return buildSummary(await loadSessionGraph(session.id, tx));
});

const resumeChecklistSession = async ({ sessionId, resumedByUserId = null, metadata = {} }) => db.transaction(async (tx) => {
  const graph = await loadSessionOrThrow(sessionId, tx);
  if (IMMUTABLE_SESSION_STATUSES.includes(graph.session.state)) {
    throw conflictError('CHECKLIST_SESSION_NOT_RESUMABLE', 'La session ne peut pas être reprise');
  }

  const updatedAt = now();
  await tx.update(tenantChecklistSessionsTable).set({
    state: 'in_progress',
    resumedAt: updatedAt,
    resumedByUserId,
    metadata: { ...(graph.session.metadata || {}), ...metadata },
    updatedAt,
  }).where(eq(tenantChecklistSessionsTable.id, sessionId));

  await createChecklistEvent(tx, {
    sessionId,
    eventType: 'session_resumed',
    actorUserId: resumedByUserId,
    fromState: graph.session.state,
    toState: 'in_progress',
    payload: { metadata },
    createdAt: updatedAt,
  });

  return buildSummary(await loadSessionGraph(sessionId, tx));
});

const pauseChecklistSession = async ({ sessionId, pausedByUserId = null, reason = null, metadata = {} }) => db.transaction(async (tx) => {
  const graph = await loadSessionOrThrow(sessionId, tx);
  if (IMMUTABLE_SESSION_STATUSES.includes(graph.session.state)) {
    throw conflictError('CHECKLIST_SESSION_NOT_PAUSABLE', 'La session ne peut pas être mise en pause');
  }

  const updatedAt = now();
  await tx.update(tenantChecklistSessionsTable).set({
    state: 'paused',
    pausedAt: updatedAt,
    pausedByUserId,
    pausedReason: reason || null,
    metadata: { ...(graph.session.metadata || {}), ...metadata },
    updatedAt,
  }).where(eq(tenantChecklistSessionsTable.id, sessionId));

  await createChecklistEvent(tx, {
    sessionId,
    eventType: 'session_paused',
    actorUserId: pausedByUserId,
    fromState: graph.session.state,
    toState: 'paused',
    payload: { reason: reason || null, metadata },
    createdAt: updatedAt,
  });

  return buildSummary(await loadSessionGraph(sessionId, tx));
});

const submitChecklistSession = async ({
  sessionId,
  submittedByUserId = null,
  confirmationNote = null,
  forceComplete = false,
  stepUpdates = [],
  attachments = [],
  signatures = [],
  metadata = {},
}) => db.transaction(async (tx) => {
  const graph = await loadSessionOrThrow(sessionId, tx);
  if (IMMUTABLE_SESSION_STATUSES.includes(graph.session.state)) {
    throw conflictError('CHECKLIST_SESSION_IMMUTABLE', 'La session complétée est immuable');
  }

  const updatedAt = now();

  if (stepUpdates.length) {
    await updateStepRows(tx, sessionId, stepUpdates);
  }

  if (attachments.length) {
    await createAttachments(tx, sessionId, attachments);
  }

  if (signatures.length) {
    await createSignatures(tx, sessionId, signatures);
  }

  const freshGraph = await loadSessionGraph(sessionId, tx);
  const allRequiredComplete = freshGraph.steps.every((step) => ['completed', 'skipped'].includes(step.status));
  const nextState = forceComplete || allRequiredComplete ? 'completed' : 'awaiting_confirmation';

  if (nextState === 'completed') {
    await tx.update(tenantChecklistSessionsTable).set({
      state: nextState,
      completedAt: updatedAt,
      submittedAt: updatedAt,
      submittedByUserId,
      confirmationNote: confirmationNote || null,
      metadata: { ...(graph.session.metadata || {}), ...metadata },
      updatedAt,
    }).where(eq(tenantChecklistSessionsTable.id, sessionId));
  } else {
    await tx.update(tenantChecklistSessionsTable).set({
      state: nextState,
      submittedAt: updatedAt,
      submittedByUserId,
      confirmationNote: confirmationNote || null,
      metadata: { ...(graph.session.metadata || {}), ...metadata },
      updatedAt,
    }).where(eq(tenantChecklistSessionsTable.id, sessionId));
  }

  await createChecklistEvent(tx, {
    sessionId,
    eventType: 'session_submitted',
    actorUserId: submittedByUserId,
    fromState: graph.session.state,
    toState: nextState,
    payload: { confirmationNote: confirmationNote || null, forceComplete, metadata },
    createdAt: updatedAt,
  });

  return buildSummary(await loadSessionGraph(sessionId, tx));
});

const getChecklistSessionSummary = async ({ sessionId }) => {
  const graph = await loadSessionOrThrow(sessionId);
  return buildSummary(graph);
};

module.exports = {
  VALID_CHECKLIST_TYPES,
  VALID_SESSION_STATUSES,
  VALID_STEP_STATUSES,
  startChecklistSession,
  resumeChecklistSession,
  pauseChecklistSession,
  submitChecklistSession,
  getChecklistSessionSummary,
  loadSessionGraph,
  buildSummary,
  buildStepRows,
};
