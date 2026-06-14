const {
  eq, and, desc, asc, ilike, sql,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const { leadsTable } = require('../database/schema');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');
const { child } = require('../utils/logger');
const leasingService = require('../services/leasing.service');

const log = child({ controller: 'lead' });

// ─── Create Lead ───
exports.createLead = async (req, res) => {
  try {
    const {
      fullName, email, phone, budgetCents, desiredUnit, source, stage,
      qualificationState, qualificationReasonCode, qualificationReasonNote,
      notes, tags, language, assignedEmployeeId, buildingId, unitId,
    } = req.body;

    if (!fullName || !fullName.trim()) {
      return res.status(400).json({
        success: false,
        error: { message: 'Full name is required', code: 'VALIDATION_ERROR' },
      });
    }

    const [lead] = await db
      .insert(leadsTable)
      .values({
        fullName: fullName.trim(),
        email: email?.trim() || null,
        phone: phone?.trim() || null,
        budgetCents: budgetCents ?? null,
        desiredUnit: desiredUnit?.trim() || null,
        source: source || 'other',
        stage: stage || 'nouveau',
        qualificationState: qualificationState || 'unknown',
        qualificationReasonCode: qualificationReasonCode || null,
        qualificationReasonNote: qualificationReasonNote?.trim() || null,
        notes: notes?.trim() || null,
        tags: tags || [],
        language: language || 'fr',
        assignedEmployeeId: assignedEmployeeId || null,
        buildingId: buildingId || null,
        unitId: unitId || null,
      })
      .returning();

    res.status(201).json({ success: true, data: lead, message: 'Lead created successfully' });
  } catch (error) {
    log.error('Error creating lead', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Referenced resource not found', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_CREATION_FAILED' },
    });
  }
};

// ─── Get Leads (paginated, filterable) ───
exports.getLeads = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      stage,
      buildingId,
      search,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    // Build conditions
    const conditions = [];
    if (stage) {conditions.push(eq(leadsTable.stage, stage));}
    if (buildingId) {conditions.push(eq(leadsTable.buildingId, buildingId));}
    if (search) {
      conditions.push(
        ilike(leadsTable.fullName, `%${search}%`),
      );
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    // Count
    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(leadsTable)
      .where(whereClause);

    // Sort
    const allowedSortFields = {
      fullName: leadsTable.fullName,
      email: leadsTable.email,
      stage: leadsTable.stage,
      source: leadsTable.source,
      createdAt: leadsTable.createdAt,
      updatedAt: leadsTable.updatedAt,
    };
    const sortColumn = allowedSortFields[sortBy] || leadsTable.createdAt;
    const orderFn = sortOrder === 'asc' ? asc : desc;

    // Data
    const leads = await db
      .select()
      .from(leadsTable)
      .where(whereClause)
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: leads,
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching leads', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_FETCH_FAILED' },
    });
  }
};

// ─── Get Lead By ID ───
exports.getLeadById = async (req, res) => {
  try {
    const { id } = req.params;

    const [lead] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, id))
      .limit(1);

    if (!lead) {
      return res.status(404).json({
        success: false,
        error: { message: 'Lead not found', code: 'LEAD_NOT_FOUND' },
      });
    }

    res.json({ success: true, data: lead });
  } catch (error) {
    log.error('Error fetching lead', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_FETCH_FAILED' },
    });
  }
};

// ─── Update Lead ───
exports.updateLead = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      fullName, email, phone, budgetCents, desiredUnit, source, stage,
      qualificationState, qualificationReasonCode, qualificationReasonNote,
      notes, tags, language, assignedEmployeeId, buildingId, unitId, isActive,
    } = req.body;

    // Check existence
    const [existing] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Lead not found', code: 'LEAD_NOT_FOUND' },
      });
    }

    // Build update payload (only include provided fields)
    const updateData = { updatedAt: new Date() };
    if (fullName !== undefined) {updateData.fullName = fullName.trim();}
    if (email !== undefined) {updateData.email = email?.trim() || null;}
    if (phone !== undefined) {updateData.phone = phone?.trim() || null;}
    if (budgetCents !== undefined) {updateData.budgetCents = budgetCents;}
    if (desiredUnit !== undefined) {updateData.desiredUnit = desiredUnit?.trim() || null;}
    if (source !== undefined) {updateData.source = source;}
    if (stage !== undefined) {
      if (!VALID_LEAD_STAGES.includes(stage)) {
        return res.status(400).json({
          success: false,
          error: {
            message: `Invalid stage. Must be one of: ${VALID_LEAD_STAGES.join(', ')}`,
            code: 'VALIDATION_ERROR',
          },
        });
      }
      updateData.stage = stage;
    }
    if (qualificationState !== undefined) {updateData.qualificationState = qualificationState;}
    if (qualificationReasonCode !== undefined) {updateData.qualificationReasonCode = qualificationReasonCode || null;}
    if (qualificationReasonNote !== undefined) {
      updateData.qualificationReasonNote = qualificationReasonNote?.trim() || null;
    }
    if (notes !== undefined) {updateData.notes = notes?.trim() || null;}
    if (tags !== undefined) {updateData.tags = tags;}
    if (language !== undefined) {updateData.language = language;}
    if (assignedEmployeeId !== undefined) {updateData.assignedEmployeeId = assignedEmployeeId || null;}
    if (buildingId !== undefined) {updateData.buildingId = buildingId || null;}
    if (unitId !== undefined) {updateData.unitId = unitId || null;}
    if (isActive !== undefined) {updateData.isActive = isActive;}

    const [updated] = await db
      .update(leadsTable)
      .set(updateData)
      .where(eq(leadsTable.id, id))
      .returning();

    res.json({ success: true, data: updated, message: 'Lead updated successfully' });
  } catch (error) {
    log.error('Error updating lead', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Referenced resource not found', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Lead (soft delete) ───
exports.deleteLead = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Lead not found', code: 'LEAD_NOT_FOUND' },
      });
    }

    await db
      .update(leadsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(leadsTable.id, id));

    res.json({ success: true, data: null, message: 'Lead deleted successfully' });
  } catch (error) {
    log.error('Error deleting lead', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_DELETE_FAILED' },
    });
  }
};

// ─── Update Lead Status (stage) ───
exports.updateLeadStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { stage } = req.body;

    if (!stage || !VALID_LEAD_STAGES.includes(stage)) {
      return res.status(400).json({
        success: false,
        error: {
          message: `Invalid stage. Must be one of: ${VALID_LEAD_STAGES.join(', ')}`,
          code: 'VALIDATION_ERROR',
        },
      });
    }

    const [existing] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Lead not found', code: 'LEAD_NOT_FOUND' },
      });
    }

    const [updated] = await db
      .update(leadsTable)
      .set({ stage, updatedAt: new Date() })
      .where(eq(leadsTable.id, id))
      .returning();

    res.json({ success: true, data: updated, message: 'Lead status updated successfully' });
  } catch (error) {
    log.error('Error updating lead status', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_STATUS_UPDATE_FAILED' },
    });
  }
};

// ─── Marketplace Webhook (Kijiji / Facebook Marketplace → Hermes) ───
exports.receiveMarketplaceWebhook = async (req, res) => {
  try {
    const expectedSecret = process.env.MARKETPLACE_WEBHOOK_SECRET;
    if (expectedSecret) {
      const provided = req.headers['x-marketplace-secret'];
      if (provided !== expectedSecret) {
        return res.status(401).json({
          success: false,
          error: { message: 'Invalid webhook secret', code: 'UNAUTHORIZED' },
        });
      }
    }

    const lead = await leasingService.ingestMarketplaceLead(req.body || {});
    const hermes = await leasingService.notifyHermes('lead.created', lead);

    res.status(201).json({
      success: true,
      data: { lead, hermesNotified: hermes.delivered },
      message: 'Marketplace lead ingested successfully',
    });
  } catch (error) {
    log.error('Error ingesting marketplace lead', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'MARKETPLACE_INGEST_FAILED' },
    });
  }
};

// ─── Trigger Hermes Qualification ───
exports.notifyHermesForLead = async (req, res) => {
  try {
    const { id } = req.params;

    const [lead] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, id))
      .limit(1);

    if (!lead) {
      return res.status(404).json({
        success: false,
        error: { message: 'Lead not found', code: 'LEAD_NOT_FOUND' },
      });
    }

    const hermes = await leasingService.notifyHermes('lead.qualify_request', lead);

    res.json({
      success: true,
      data: { hermesNotified: hermes.delivered, reason: hermes.reason || null },
      message: hermes.delivered ? 'Hermes notified' : 'Hermes notification skipped',
    });
  } catch (error) {
    log.error('Error notifying Hermes', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'HERMES_NOTIFY_FAILED' },
    });
  }
};

// ─── Bulk Update Leads ───
exports.bulkUpdateLeads = async (req, res) => {
  try {
    const { ids, updates } = req.body;

    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({
        success: false,
        error: { message: 'ids must be a non-empty array', code: 'VALIDATION_ERROR' },
      });
    }

    if (!updates || typeof updates !== 'object') {
      return res.status(400).json({
        success: false,
        error: { message: 'updates must be an object', code: 'VALIDATION_ERROR' },
      });
    }

    // Only allow safe fields in bulk update
    const allowedFields = ['stage', 'assignedEmployeeId', 'buildingId', 'isActive', 'tags', 'language'];
    const updateData = { updatedAt: new Date() };

    for (const key of Object.keys(updates)) {
      if (!allowedFields.includes(key)) {
        return res.status(400).json({
          success: false,
          error: { message: `Field '${key}' is not allowed for bulk update`, code: 'VALIDATION_ERROR' },
        });
      }
      updateData[key] = updates[key];
    }

    // Validate stage if present
    if (updates.stage && !VALID_LEAD_STAGES.includes(updates.stage)) {
      return res.status(400).json({
        success: false,
        error: { message: 'Invalid stage value', code: 'VALIDATION_ERROR' },
      });
    }

    // Execute bulk update — one query per id (Drizzle doesn't have bulk where-in easily)
    // Use SQL for efficiency
    await db
      .update(leadsTable)
      .set(updateData)
      .where(sql`${leadsTable.id} = ANY(${ids})`);

    res.json({
      success: true,
      data: { updatedCount: ids.length },
      message: `${ids.length} lead(s) updated successfully`,
    });
  } catch (error) {
    log.error('Error bulk updating leads', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'LEAD_BULK_UPDATE_FAILED' },
    });
  }
};
