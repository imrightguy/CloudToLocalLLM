const { eq, and, desc, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const { observationResultsTable } = require('../database/schema');
const { child } = require('../utils/logger');

const log = child({ controller: 'observation-result' });

const success = (res, data, message, metadata) => {
  const payload = { success: true, data, message };
  if (metadata) { payload.metadata = metadata; }
  return res.json(payload);
};

const error = (res, status, code, message) => res.status(status).json({
  success: false,
  error: { code, message },
});

const normalizeImportPayload = (body) => (Array.isArray(body) ? body : [body]);

exports.importObservationResults = async (req, res) => {
  try {
    const items = normalizeImportPayload(req.body);
    const imported = [];

    for (const item of items) {
      const [row] = await db.insert(observationResultsTable).values({
        companyId: req.params.companyId,
        projectId: item.projectId || null,
        domain: item.domain,
        sourceKind: item.sourceKind,
        sourceRef: item.sourceRef || null,
        sourceFingerprint: item.sourceFingerprint || null,
        title: item.title,
        summary: item.summary,
        details: item.details || {},
        privacyClass: item.privacyClass || 'redacted',
        confidence: item.confidence ?? null,
        status: 'new',
        leadId: item.leadId || null,
        communicationLogId: item.communicationLogId || null,
        visitId: item.visitId || null,
        followUpType: item.followUpType || null,
        followUpDueAt: item.followUpDueAt || null,
      }).returning();
      imported.push(row);
    }

    return res.status(201).json({ success: true, data: imported, message: 'Observation results imported successfully' });
  } catch (err) {
    log.error('Error importing observation results', { error: err.message });
    return error(res, 500, 'OBSERVATION_RESULT_IMPORT_FAILED', 'Internal server error');
  }
};

exports.listObservationResults = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;

    const conditions = [eq(observationResultsTable.companyId, req.params.companyId)];
    if (req.query.status) { conditions.push(eq(observationResultsTable.status, req.query.status)); }
    if (req.query.domain) { conditions.push(eq(observationResultsTable.domain, req.query.domain)); }
    if (req.query.leadId) { conditions.push(eq(observationResultsTable.leadId, req.query.leadId)); }
    if (req.query.visitId) { conditions.push(eq(observationResultsTable.visitId, req.query.visitId)); }
    if (req.query.communicationLogId) { conditions.push(eq(observationResultsTable.communicationLogId, req.query.communicationLogId)); }
    if (req.query.followUpType) { conditions.push(eq(observationResultsTable.followUpType, req.query.followUpType)); }
    if (req.query.sourceKind) { conditions.push(eq(observationResultsTable.sourceKind, req.query.sourceKind)); }
    if (req.query.projectId) { conditions.push(eq(observationResultsTable.projectId, req.query.projectId)); }

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` })
      .from(observationResultsTable)
      .where(and(...conditions));
    const rows = await db.select()
      .from(observationResultsTable)
      .where(and(...conditions))
      .orderBy(desc(observationResultsTable.createdAt))
      .limit(limit)
      .offset(offset);

    return success(res, rows, 'Observation results retrieved successfully', {
      total,
      page,
      limit,
      totalPages: Math.ceil((total || 0) / limit) || 0,
      hasMore: page * limit < total,
    });
  } catch (err) {
    log.error('Error listing observation results', { error: err.message });
    return error(res, 500, 'OBSERVATION_RESULT_LIST_FAILED', 'Internal server error');
  }
};

exports.getObservationResultById = async (req, res) => {
  try {
    const [row] = await db.select()
      .from(observationResultsTable)
      .where(and(
        eq(observationResultsTable.companyId, req.params.companyId),
        eq(observationResultsTable.id, req.params.id),
      ))
      .limit(1);

    if (!row) {
      return error(res, 404, 'OBSERVATION_RESULT_NOT_FOUND', 'Observation result not found');
    }

    return success(res, row, 'Observation result retrieved successfully');
  } catch (err) {
    log.error('Error fetching observation result', { error: err.message });
    return error(res, 500, 'OBSERVATION_RESULT_FETCH_FAILED', 'Internal server error');
  }
};

exports.reviewObservationResult = async (req, res) => {
  try {
    const [existing] = await db.select()
      .from(observationResultsTable)
      .where(and(
        eq(observationResultsTable.companyId, req.params.companyId),
        eq(observationResultsTable.id, req.params.id),
      ))
      .limit(1);

    if (!existing) {
      return error(res, 404, 'OBSERVATION_RESULT_NOT_FOUND', 'Observation result not found');
    }

    const updates = {
      status: 'reviewed',
      reviewedByUserId: req.user?.id || null,
      reviewedAt: new Date(),
      updatedAt: new Date(),
    };

    if (req.body.title !== undefined) { updates.title = req.body.title; }
    if (req.body.summary !== undefined) { updates.summary = req.body.summary; }
    if (req.body.details !== undefined) { updates.details = req.body.details; }
    if (req.body.confidence !== undefined) { updates.confidence = req.body.confidence; }
    if (req.body.projectId !== undefined) { updates.projectId = req.body.projectId; }
    if (req.body.leadId !== undefined) { updates.leadId = req.body.leadId; }
    if (req.body.visitId !== undefined) { updates.visitId = req.body.visitId; }
    if (req.body.communicationLogId !== undefined) { updates.communicationLogId = req.body.communicationLogId; }
    if (req.body.followUpType !== undefined) { updates.followUpType = req.body.followUpType; }
    if (req.body.followUpDueAt !== undefined) { updates.followUpDueAt = req.body.followUpDueAt; }

    const [updated] = await db.update(observationResultsTable)
      .set(updates)
      .where(and(
        eq(observationResultsTable.companyId, req.params.companyId),
        eq(observationResultsTable.id, req.params.id),
      ))
      .returning();

    return success(res, updated, 'Observation result reviewed successfully');
  } catch (err) {
    log.error('Error reviewing observation result', { error: err.message });
    return error(res, 500, 'OBSERVATION_RESULT_REVIEW_FAILED', 'Internal server error');
  }
};

exports.dismissObservationResult = async (req, res) => {
  try {
    const [existing] = await db.select()
      .from(observationResultsTable)
      .where(and(
        eq(observationResultsTable.companyId, req.params.companyId),
        eq(observationResultsTable.id, req.params.id),
      ))
      .limit(1);

    if (!existing) {
      return error(res, 404, 'OBSERVATION_RESULT_NOT_FOUND', 'Observation result not found');
    }

    const [updated] = await db.update(observationResultsTable)
      .set({
        status: 'dismissed',
        dismissedAt: new Date(),
        dismissalReason: req.body.reason || null,
        updatedAt: new Date(),
      })
      .where(and(
        eq(observationResultsTable.companyId, req.params.companyId),
        eq(observationResultsTable.id, req.params.id),
      ))
      .returning();

    return success(res, updated, 'Observation result dismissed successfully');
  } catch (err) {
    log.error('Error dismissing observation result', { error: err.message });
    return error(res, 500, 'OBSERVATION_RESULT_DISMISS_FAILED', 'Internal server error');
  }
};
