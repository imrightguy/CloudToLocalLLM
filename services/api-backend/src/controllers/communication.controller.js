const {
  eq, and, desc, sql, gte,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  communicationLogsTable, leadsTable, visitsTable, smsLogsTable, employeesTable, unitsTable, buildingsTable,
} = require('../database/schema');
const { child } = require('../utils/logger');

const log = child({ controller: 'communication' });

// ─── Log Communication ───
exports.logCommunication = async (req, res) => {
  try {
    const {
      leadId, employeeId, type, direction, content, subject, attachments, status, metadata,
    } = req.body;

    const validTypes = ['sms', 'email', 'phone', 'fb_messenger'];
    const validDirections = ['inbound', 'outbound'];

    if (!type || !validTypes.includes(type)) {
      return res.status(400).json({
        success: false,
        error: { message: `type is required and must be one of: ${validTypes.join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }

    if (!direction || !validDirections.includes(direction)) {
      return res.status(400).json({
        success: false,
        error: { message: `direction is required and must be one of: ${validDirections.join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }

    const [record] = await db.insert(communicationLogsTable).values({
      leadId: leadId || null,
      employeeId: employeeId || null,
      type,
      direction,
      content: content || null,
      subject: subject || null,
      attachments: attachments || [],
      status: status || 'sent',
      metadata: metadata || {},
      isActive: true,
    }).returning();

    res.status(201).json({
      success: true,
      data: record,
      message: 'Communication logged successfully',
    });
  } catch (error) {
    log.error('Error logging communication', { error: error.message });
    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Invalid leadId or employeeId', code: 'FOREIGN_KEY_ERROR' },
      });
    }
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'COMMUNICATION_LOG_FAILED' },
    });
  }
};

// ─── Get Communications (filterable) ───
exports.getCommunications = async (req, res) => {
  try {
    const {
      leadId, employeeId, type, direction, status, page = 1, limit = 20,
    } = req.query;
    const validPage = Math.max(1, parseInt(page) || 1);
    const validLimit = Math.min(100, Math.max(1, parseInt(limit) || 20));
    const offset = (validPage - 1) * validLimit;

    const conditions = [eq(communicationLogsTable.isActive, true)];
    if (leadId) {conditions.push(eq(communicationLogsTable.leadId, leadId));}
    if (employeeId) {conditions.push(eq(communicationLogsTable.employeeId, employeeId));}
    if (type) {conditions.push(eq(communicationLogsTable.type, type));}
    if (direction) {conditions.push(eq(communicationLogsTable.direction, direction));}
    if (status) {conditions.push(eq(communicationLogsTable.status, status));}

    // Count
    const countResult = await db.select({ count: sql`count(*)::int` })
      .from(communicationLogsTable)
      .where(and(...conditions));
    const total = countResult[0]?.count || 0;

    // Data
    const communications = await db.select()
      .from(communicationLogsTable)
      .where(and(...conditions))
      .orderBy(desc(communicationLogsTable.createdAt))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: communications,
      message: 'Communications retrieved successfully',
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching communications', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'COMMUNICATION_FETCH_FAILED' },
    });
  }
};

// ─── Get Communication Log By ID ───
exports.getCommunicationLogById = async (req, res) => {
  try {
    const { id } = req.params;

    const [record] = await db.select()
      .from(communicationLogsTable)
      .where(and(
        eq(communicationLogsTable.id, id),
        eq(communicationLogsTable.isActive, true),
      ))
      .limit(1);

    if (!record || record.isActive === false) {
      return res.status(404).json({
        success: false,
        error: { message: 'Communication log not found', code: 'COMMUNICATION_NOT_FOUND' },
      });
    }

    res.json({
      success: true,
      data: record,
      message: 'Communication log retrieved successfully',
    });
  } catch (error) {
    log.error('Error fetching communication log', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'COMMUNICATION_FETCH_FAILED' },
    });
  }
};

// ─── Update Communication Log ───
exports.updateCommunicationLog = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      content, subject, attachments, status, metadata,
    } = req.body;

    const [existing] = await db.select()
      .from(communicationLogsTable)
      .where(and(
        eq(communicationLogsTable.id, id),
        eq(communicationLogsTable.isActive, true),
      ))
      .limit(1);

    if (!existing || existing.isActive === false) {
      return res.status(404).json({
        success: false,
        error: { message: 'Journal de communication introuvable', code: 'COMMUNICATION_NOT_FOUND' },
      });
    }

    const validStatuses = ['sent', 'delivered', 'read', 'failed'];
    if (status !== undefined && !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: { message: `Statut invalide. Valeurs acceptées : ${validStatuses.join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }

    const updateData = {};
    if (content !== undefined) {updateData.content = content;}
    if (subject !== undefined) {updateData.subject = subject;}
    if (attachments !== undefined) {updateData.attachments = attachments;}
    if (status !== undefined) {updateData.status = status;}
    if (metadata !== undefined) {updateData.metadata = metadata;}

    const [updated] = await db.update(communicationLogsTable)
      .set(updateData)
      .where(and(
        eq(communicationLogsTable.id, id),
        eq(communicationLogsTable.isActive, true),
      ))
      .returning();

    if (!updated || updated.isActive === false) {
      return res.status(404).json({
        success: false,
        error: { message: 'Journal de communication introuvable', code: 'COMMUNICATION_NOT_FOUND' },
      });
    }

    res.json({
      success: true,
      data: updated,
      message: 'Journal de communication mis à jour avec succès',
    });
  } catch (error) {
    log.error('Error updating communication log', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'COMMUNICATION_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Communication Log (soft delete) ───
exports.deleteCommunicationLog = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(communicationLogsTable)
      .where(and(
        eq(communicationLogsTable.id, id),
        eq(communicationLogsTable.isActive, true),
      ))
      .limit(1);

    if (!existing || existing.isActive === false) {
      return res.status(404).json({
        success: false,
        error: { message: 'Journal de communication introuvable', code: 'COMMUNICATION_NOT_FOUND' },
      });
    }

    const [deleted] = await db.update(communicationLogsTable)
      .set({ isActive: false })
      .where(and(
        eq(communicationLogsTable.id, id),
        eq(communicationLogsTable.isActive, true),
      ))
      .returning({ id: communicationLogsTable.id, isActive: communicationLogsTable.isActive });

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: { message: 'Journal de communication introuvable', code: 'COMMUNICATION_NOT_FOUND' },
      });
    }

    res.json({
      success: true,
      data: null,
      message: 'Journal de communication supprimé avec succès',
    });
  } catch (error) {
    log.error('Error deleting communication log', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'COMMUNICATION_DELETE_FAILED' },
    });
  }
};

// ─── Get Communication Logs (alias for getCommunications) ───
exports.getCommunicationLogs = async (req, res) => exports.getCommunications(req, res);

// ─── Activity Feed ───
// Unified feed aggregating recent activity from leads, visits, and SMS/communications.
// GET /api/communications/activity?type=lead_created,visit_scheduled,sms_sent&limit=30&hoursAgo=168
exports.getActivityFeed = async (req, res) => {
  try {
    const {
      limit = 30,
      hoursAgo = 168, // default: 7 days
      // comma-separated filter: lead_created, visit_scheduled, visit_completed,
      // sms_sent, sms_received, communication_logged
      type,
    } = req.query;

    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const validHoursAgo = Math.min(720, Math.max(1, parseInt(hoursAgo))); // max 30 days
    const since = new Date(Date.now() - validHoursAgo * 60 * 60 * 1000);

    // Parse type filter
    const allTypes = [
      'lead_created', 'visit_scheduled', 'visit_completed',
      'sms_sent', 'sms_received', 'communication_logged',
    ];
    const filterTypes = type
      ? type.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t))
      : null; // null = all types

    const activities = [];

    // 1. New leads
    if (!filterTypes || filterTypes.includes('lead_created')) {
      const newLeads = await db
        .select({
          id: leadsTable.id,
          fullName: leadsTable.fullName,
          phone: leadsTable.phone,
          source: leadsTable.source,
          stage: leadsTable.stage,
          createdAt: leadsTable.createdAt,
        })
        .from(leadsTable)
        .where(and(
          eq(leadsTable.isActive, true),
          gte(leadsTable.createdAt, since),
        ))
        .orderBy(desc(leadsTable.createdAt))
        .limit(validLimit);

      for (const lead of newLeads) {
        activities.push({
          type: 'lead_created',
          description: `Nouveau prospect : ${lead.fullName}${lead.source !== 'other' ? ` (via ${lead.source})` : ''}`,
          timestamp: lead.createdAt,
          leadId: lead.id,
          metadata: {
            fullName: lead.fullName,
            phone: lead.phone,
            source: lead.source,
            stage: lead.stage,
          },
        });
      }
    }

    // 2. Visits scheduled (status = scheduled or confirmed)
    if (!filterTypes || filterTypes.includes('visit_scheduled')) {
      const scheduledVisits = await db
        .select({
          id: visitsTable.id,
          dateTime: visitsTable.dateTime,
          leadFullName: leadsTable.fullName,
          employeeFirstName: employeesTable.firstName,
          employeeLastName: employeesTable.lastName,
          unitLabel: unitsTable.label,
          buildingName: buildingsTable.name,
          createdAt: visitsTable.createdAt,
        })
        .from(visitsTable)
        .leftJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
        .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
        .leftJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
        .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
        .where(and(
          eq(visitsTable.isActive, true),
          sql`${visitsTable.status} IN ('scheduled', 'confirmed')`,
          gte(visitsTable.createdAt, since),
        ))
        .orderBy(desc(visitsTable.createdAt))
        .limit(validLimit);

      for (const visit of scheduledVisits) {
        const dateStr = visit.dateTime
          ? new Date(visit.dateTime).toLocaleDateString('fr-CA', {
            day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
          })
          : '';
        activities.push({
          type: 'visit_scheduled',
          description: `Visite planifiée : ${visit.leadFullName || 'Prospect'} avec ${visit.employeeFirstName || ''} ${visit.employeeLastName || ''} — ${visit.unitLabel || ''}${visit.buildingName ? ` (${visit.buildingName})` : ''} le ${dateStr}`,
          timestamp: visit.createdAt,
          visitId: visit.id,
          metadata: {
            leadFullName: visit.leadFullName,
            employeeName: `${visit.employeeFirstName || ''} ${visit.employeeLastName || ''}`.trim(),
            unitLabel: visit.unitLabel,
            buildingName: visit.buildingName,
            scheduledFor: visit.dateTime,
          },
        });
      }
    }

    // 3. Visits completed
    if (!filterTypes || filterTypes.includes('visit_completed')) {
      const completedVisits = await db
        .select({
          id: visitsTable.id,
          dateTime: visitsTable.dateTime,
          outcome: visitsTable.outcome,
          leadFullName: leadsTable.fullName,
          employeeFirstName: employeesTable.firstName,
          employeeLastName: employeesTable.lastName,
          unitLabel: unitsTable.label,
          updatedAt: visitsTable.updatedAt,
        })
        .from(visitsTable)
        .leftJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
        .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
        .leftJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
        .where(and(
          eq(visitsTable.isActive, true),
          eq(visitsTable.status, 'completed'),
          gte(visitsTable.updatedAt, since),
        ))
        .orderBy(desc(visitsTable.updatedAt))
        .limit(validLimit);

      for (const visit of completedVisits) {
        const outcomeMap = {
          interesse: ' — intéressé',
          pas_interesse: ' — pas intéressé',
          no_show: ' — absent',
        };
        const outcomeText = outcomeMap[visit.outcome] || '';
        activities.push({
          type: 'visit_completed',
          description: `Visite terminée : ${visit.leadFullName || 'Prospect'} — ${visit.unitLabel || ''}${outcomeText}`,
          timestamp: visit.updatedAt,
          visitId: visit.id,
          metadata: {
            leadFullName: visit.leadFullName,
            employeeName: `${visit.employeeFirstName || ''} ${visit.employeeLastName || ''}`.trim(),
            unitLabel: visit.unitLabel,
            outcome: visit.outcome,
          },
        });
      }
    }

    // 4. SMS sent
    if (!filterTypes || filterTypes.includes('sms_sent')) {
      const sentSms = await db
        .select({
          id: smsLogsTable.id,
          phoneNumber: smsLogsTable.phoneNumber,
          direction: smsLogsTable.direction,
          status: smsLogsTable.status,
          leadFullName: leadsTable.fullName,
          createdAt: smsLogsTable.createdAt,
        })
        .from(smsLogsTable)
        .leftJoin(leadsTable, eq(smsLogsTable.leadId, leadsTable.id))
        .where(and(
          eq(smsLogsTable.isActive, true),
          eq(smsLogsTable.direction, 'outbound'),
          gte(smsLogsTable.createdAt, since),
        ))
        .orderBy(desc(smsLogsTable.createdAt))
        .limit(validLimit);

      for (const sms of sentSms) {
        activities.push({
          type: 'sms_sent',
          description: `SMS envoyé à ${sms.leadFullName || sms.phoneNumber}`,
          timestamp: sms.createdAt,
          smsLogId: sms.id,
          metadata: {
            phoneNumber: sms.phoneNumber,
            leadFullName: sms.leadFullName,
            status: sms.status,
          },
        });
      }
    }

    // 5. SMS received (inbound)
    if (!filterTypes || filterTypes.includes('sms_received')) {
      const receivedSms = await db
        .select({
          id: smsLogsTable.id,
          phoneNumber: smsLogsTable.phoneNumber,
          status: smsLogsTable.status,
          leadFullName: leadsTable.fullName,
          createdAt: smsLogsTable.createdAt,
        })
        .from(smsLogsTable)
        .leftJoin(leadsTable, eq(smsLogsTable.leadId, leadsTable.id))
        .where(and(
          eq(smsLogsTable.isActive, true),
          eq(smsLogsTable.direction, 'inbound'),
          gte(smsLogsTable.createdAt, since),
        ))
        .orderBy(desc(smsLogsTable.createdAt))
        .limit(validLimit);

      for (const sms of receivedSms) {
        activities.push({
          type: 'sms_received',
          description: `SMS reçu de ${sms.leadFullName || sms.phoneNumber}`,
          timestamp: sms.createdAt,
          smsLogId: sms.id,
          metadata: {
            phoneNumber: sms.phoneNumber,
            leadFullName: sms.leadFullName,
            status: sms.status,
          },
        });
      }
    }

    // 6. Communication logs (non-SMS)
    if (!filterTypes || filterTypes.includes('communication_logged')) {
      const comms = await db
        .select({
          id: communicationLogsTable.id,
          type: communicationLogsTable.type,
          direction: communicationLogsTable.direction,
          leadFullName: leadsTable.fullName,
          subject: communicationLogsTable.subject,
          createdAt: communicationLogsTable.createdAt,
        })
        .from(communicationLogsTable)
        .leftJoin(leadsTable, eq(communicationLogsTable.leadId, leadsTable.id))
        .where(and(
          eq(communicationLogsTable.isActive, true),
          sql`${communicationLogsTable.type} != 'sms'`,
          gte(communicationLogsTable.createdAt, since),
        ))
        .orderBy(desc(communicationLogsTable.createdAt))
        .limit(validLimit);

      for (const comm of comms) {
        const typeLabels = { email: 'E-mail', phone: 'Appel', fb_messenger: 'Messenger' };
        const label = typeLabels[comm.type] || comm.type;
        const dirLabel = comm.direction === 'inbound' ? ' reçu de' : ' envoyé à';
        activities.push({
          type: 'communication_logged',
          description: `${label}${dirLabel} ${comm.leadFullName || 'contact'}${comm.subject ? ` — ${comm.subject}` : ''}`,
          timestamp: comm.createdAt,
          communicationLogId: comm.id,
          metadata: {
            communicationType: comm.type,
            direction: comm.direction,
            leadFullName: comm.leadFullName,
            subject: comm.subject,
          },
        });
      }
    }

    // Sort all activities by timestamp descending, then limit
    activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    const result = activities.slice(0, validLimit);

    res.json({
      success: true,
      data: result,
      metadata: {
        total: result.length,
        limit: validLimit,
        hoursAgo: validHoursAgo,
        types: filterTypes || allTypes,
      },
    });
  } catch (error) {
    log.error('Error fetching activity feed', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'ACTIVITY_FEED_FAILED' },
    });
  }
};
