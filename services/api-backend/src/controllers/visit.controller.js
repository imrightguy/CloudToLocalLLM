const {
  eq, and, desc, asc, sql, gte, lte,
} = require('drizzle-orm');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const {
  visitsTable, unitsTable, buildingsTable, employeesTable, leadsTable, employeeSchedulesTable,
} = require('../database/schema');
const { sendOccupantAccessRequest, sendVisitConfirmation, sendTenantConfirmationRequest } = require('../services/sms.service');
const { generateConfirmationToken } = require('./tenant-confirmation.controller');

/**
 * Check if a visit time conflicts with an employee's existing visits.
 * Two visits overlap if their time windows intersect.
 */
async function checkVisitConflict(employeeId, dateTime, durationMinutes, excludeVisitId = null) {
  const visitStart = new Date(dateTime);
  const visitEnd = new Date(visitStart.getTime() + durationMinutes * 60 * 1000);

  const conditions = [
    eq(visitsTable.employeeId, employeeId),
    eq(visitsTable.isActive, true),
    and(
      sql`${visitsTable.dateTime} < ${visitEnd}`,
      sql`${visitsTable.dateTime} + (${visitsTable.durationMinutes} || ' minutes')::interval > ${visitStart}`,
    ),
    // Exclude cancelled visits
    sql`${visitsTable.status} != 'cancelled'`,
  ];

  if (excludeVisitId) {
    conditions.push(sql`${visitsTable.id} != ${excludeVisitId}`);
  }

  const conflicts = await db
    .select({
      id: visitsTable.id,
      dateTime: visitsTable.dateTime,
      durationMinutes: visitsTable.durationMinutes,
    })
    .from(visitsTable)
    .where(and(...conditions))
    .limit(1);

  return conflicts.length > 0 ? conflicts[0] : null;
}

/**
 * Check if an employee has a valid schedule for the given day/time at the building.
 * Returns null if OK, or an error message string.
 */
async function checkScheduleAvailability(employeeId, buildingId, dateTime) {
  const dayOfWeek = dateTime.getDay(); // 0=Sunday in JS, but schema says 0=Monday
  const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Convert: JS Sun=0 → 6, Mon=1 → 0, etc.

  const timeHHMM = `${String(dateTime.getHours()).padStart(2, '0')}:${String(dateTime.getMinutes()).padStart(2, '0')}`;

  const schedules = await db
    .select()
    .from(employeeSchedulesTable)
    .where(and(
      eq(employeeSchedulesTable.employeeId, employeeId),
      eq(employeeSchedulesTable.buildingId, buildingId),
      eq(employeeSchedulesTable.dayOfWeek, scheduleDay),
      eq(employeeSchedulesTable.isActive, true),
    ))
    .limit(1);

  if (schedules.length === 0) {
    return 'Employee has no schedule for this day at this building';
  }

  const schedule = schedules[0];
  if (timeHHMM < schedule.startTime || timeHHMM >= schedule.endTime) {
    return `Visit time ${timeHHMM} is outside employee schedule (${schedule.startTime}–${schedule.endTime})`;
  }

  return null;
}

// ─── Create Visit ───
exports.createVisit = async (req, res) => {
  try {
    const {
      unitId, employeeId, leadId, dateTime, durationMinutes,
      status, notes,
    } = req.body;

    if (!unitId || !employeeId || !leadId || !dateTime) {
      return res.status(400).json({
        success: false,
        error: { message: 'unitId, employeeId, leadId, and dateTime are required', code: 'VALIDATION_ERROR' },
      });
    }

    const parsedDate = new Date(dateTime);
    if (Number.isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        error: { message: 'dateTime must be a valid ISO date string', code: 'VALIDATION_ERROR' },
      });
    }

    // Resolve buildingId from unitId for schedule check
    const [unit] = await db
      .select({ buildingId: unitsTable.buildingId })
      .from(unitsTable)
      .where(eq(unitsTable.id, unitId))
      .limit(1);

    if (!unit) {
      return res.status(400).json({
        success: false,
        error: { message: 'Unit not found', code: 'UNIT_NOT_FOUND' },
      });
    }

    // Check employee schedule availability
    const scheduleError = await checkScheduleAvailability(employeeId, unit.buildingId, parsedDate);
    if (scheduleError) {
      return res.status(409).json({
        success: false,
        error: { message: scheduleError, code: 'SCHEDULE_CONFLICT' },
      });
    }

    // Check for visit time conflicts
    const duration = durationMinutes || 30;
    const conflict = await checkVisitConflict(employeeId, parsedDate, duration);
    if (conflict) {
      return res.status(409).json({
        success: false,
        error: {
          message: 'Employee already has a visit at this time',
          code: 'VISIT_CONFLICT',
          details: { conflictingVisitId: conflict.id, conflictingTime: conflict.dateTime },
        },
      });
    }

    const [visit] = await db
      .insert(visitsTable)
      .values({
        unitId,
        employeeId,
        leadId,
        dateTime: parsedDate,
        durationMinutes: durationMinutes || 30,
        status: status || 'scheduled',
        notes: notes?.trim() || null,
        confirmationToken: generateConfirmationToken(),
      })
      .returning();

    // Send visit confirmation SMS to employee and lead (skip if cancelled)
    let confirmationResult = null;
    const visitStatus = visit.status || 'scheduled';
    if (visitStatus !== 'cancelled') {
      try {
        const employeeConfirmation = await sendVisitConfirmation(visit.id);
        const tenantConfirmation = await sendTenantConfirmationRequest(visit.id);
        confirmationResult = { employee: employeeConfirmation, tenant: tenantConfirmation };
        logger.info(`📨 Visit confirmation sent: employee=${employeeConfirmation.success}, tenant=${tenantConfirmation.success}`);
      } catch (smsErr) {
        logger.error('⚠️  Visit confirmation SMS failed (visit created anyway):', smsErr.message);
        confirmationResult = { success: false, error: smsErr.message };
      }
    }

    // Auto-send occupant access request if unit is occupied
    let occupantResult = null;
    try {
      const [unitDetails] = await db
        .select()
        .from(unitsTable)
        .where(eq(unitsTable.id, unitId))
        .limit(1);

      const isOccupied = unitDetails?.status === 'occupied' || unitDetails?.tenantPhone;
      if (isOccupied) {
        occupantResult = await sendOccupantAccessRequest(visit.id);
      }
    } catch (smsErr) {
      logger.error('⚠️  Occupant SMS failed (visit created anyway):', smsErr.message);
      occupantResult = { success: false, error: smsErr.message };
    }

    res.status(201).json({
      success: true,
      data: visit,
      confirmationSMS: confirmationResult,
      occupantSMS: occupantResult,
      message: 'Visit created successfully',
    });
  } catch (error) {
    logger.error('Error creating visit:', error);

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Referenced unit, employee, or lead not found', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_CREATION_FAILED' },
    });
  }
};

// ─── Get Visits (paginated, filterable, with expandable relations) ───
exports.getVisits = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      employeeId,
      leadId,
      dateFrom,
      dateTo,
      sortBy = 'dateTime',
      sortOrder = 'desc',
      expand, // comma-separated: unit,building,employee,lead — default: all
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    // Parse expand param — if not provided, expand all
    const allExpandOptions = ['unit', 'building', 'employee', 'lead'];
    const expandAll = !expand;
    const expandSet = expandAll
      ? new Set(allExpandOptions)
      : new Set(expand.split(',').map((s) => s.trim()).filter((s) => allExpandOptions.includes(s)));

    // Build conditions
    const conditions = [eq(visitsTable.isActive, true)];
    if (status) {conditions.push(eq(visitsTable.status, status));}
    if (employeeId) {conditions.push(eq(visitsTable.employeeId, employeeId));}
    if (leadId) {conditions.push(eq(visitsTable.leadId, leadId));}
    if (dateFrom) {
      const from = new Date(dateFrom);
      if (!Number.isNaN(from.getTime())) {
        conditions.push(gte(visitsTable.dateTime, from));
      }
    }
    if (dateTo) {
      const to = new Date(dateTo);
      if (!Number.isNaN(to.getTime())) {
        // Include the entire end day
        to.setHours(23, 59, 59, 999);
        conditions.push(lte(visitsTable.dateTime, to));
      }
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    // Count
    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(visitsTable)
      .where(whereClause);

    // Sort
    const allowedSortFields = {
      dateTime: visitsTable.dateTime,
      status: visitsTable.status,
      durationMinutes: visitsTable.durationMinutes,
      createdAt: visitsTable.createdAt,
      updatedAt: visitsTable.updatedAt,
    };
    const sortColumn = allowedSortFields[sortBy] || visitsTable.dateTime;
    const orderFn = sortOrder === 'asc' ? asc : desc;

    // Data with JOINs
    const visits = await db
      .select({
        id: visitsTable.id,
        unitId: visitsTable.unitId,
        employeeId: visitsTable.employeeId,
        leadId: visitsTable.leadId,
        dateTime: visitsTable.dateTime,
        durationMinutes: visitsTable.durationMinutes,
        status: visitsTable.status,
        tenantConfirmed: visitsTable.tenantConfirmed,
        occupantNotified: visitsTable.occupantNotified,
        employeeConfirmed: visitsTable.employeeConfirmed,
        morningOfSent: visitsTable.morningOfSent,
        outcome: visitsTable.outcome,
        notes: visitsTable.notes,
        isActive: visitsTable.isActive,
        createdAt: visitsTable.createdAt,
        updatedAt: visitsTable.updatedAt,
        // Joined fields
        ...(expandSet.has('unit') ? {
          unitLabel: unitsTable.label,
          unitRentCents: unitsTable.rentCents,
          unitStatus: unitsTable.status,
        } : {}),
        ...(expandSet.has('building') ? {
          buildingId: buildingsTable.id,
          buildingName: buildingsTable.name,
          buildingAddress: buildingsTable.address,
          buildingCity: buildingsTable.city,
        } : {}),
        ...(expandSet.has('employee') ? {
          employeeFirstName: employeesTable.firstName,
          employeeLastName: employeesTable.lastName,
          employeePhone: employeesTable.phone,
        } : {}),
        ...(expandSet.has('lead') ? {
          leadFullName: leadsTable.fullName,
          leadEmail: leadsTable.email,
          leadPhone: leadsTable.phone,
        } : {}),
      })
      .from(visitsTable)
      .leftJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
      .leftJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
      .where(whereClause)
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    // Shape response into nested objects for expanded relations
    const data = visits.map((v) => {
      const item = {
        id: v.id,
        unitId: v.unitId,
        employeeId: v.employeeId,
        leadId: v.leadId,
        dateTime: v.dateTime,
        durationMinutes: v.durationMinutes,
        status: v.status,
        tenantConfirmed: v.tenantConfirmed,
        occupantNotified: v.occupantNotified,
        employeeConfirmed: v.employeeConfirmed,
        morningOfSent: v.morningOfSent,
        outcome: v.outcome,
        notes: v.notes,
        isActive: v.isActive,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
      };

      if (expandSet.has('unit')) {
        item.unit = {
          label: v.unitLabel,
          rentCents: v.unitRentCents,
          status: v.unitStatus,
        };
      }
      if (expandSet.has('building')) {
        item.building = {
          id: v.buildingId,
          name: v.buildingName,
          address: v.buildingAddress,
          city: v.buildingCity,
        };
      }
      if (expandSet.has('employee')) {
        item.employee = {
          firstName: v.employeeFirstName,
          lastName: v.employeeLastName,
          phone: v.employeePhone,
        };
      }
      if (expandSet.has('lead')) {
        item.lead = {
          fullName: v.leadFullName,
          email: v.leadEmail,
          phone: v.leadPhone,
        };
      }

      return item;
    });

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data,
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    logger.error('Error fetching visits:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_FETCH_FAILED' },
    });
  }
};

// ─── Get Visit By ID ───
exports.getVisitById = async (req, res) => {
  try {
    const { id } = req.params;

    const [visit] = await db
      .select()
      .from(visitsTable)
      .where(eq(visitsTable.id, id))
      .limit(1);

    if (!visit) {
      return res.status(404).json({
        success: false,
        error: { message: 'Visit not found', code: 'VISIT_NOT_FOUND' },
      });
    }

    res.json({ success: true, data: visit });
  } catch (error) {
    logger.error('Error fetching visit:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_FETCH_FAILED' },
    });
  }
};

// ─── Update Visit ───
exports.updateVisit = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      unitId, employeeId, leadId, dateTime, durationMinutes,
      status, tenantConfirmed, employeeConfirmed, morningOfSent,
      outcome, notes, isActive,
    } = req.body;

    // Check existence
    const [existing] = await db
      .select()
      .from(visitsTable)
      .where(eq(visitsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Visit not found', code: 'VISIT_NOT_FOUND' },
      });
    }

    // Conflict checking on time/employee changes
    const checkDateTime = dateTime ? new Date(dateTime) : existing.dateTime;
    const checkDuration = durationMinutes !== undefined ? durationMinutes : existing.durationMinutes;
    const checkEmployee = employeeId !== undefined ? employeeId : existing.employeeId;

    if (dateTime !== undefined && Number.isNaN(checkDateTime.getTime())) {
      return res.status(400).json({
        success: false,
        error: { message: 'dateTime must be a valid ISO date string', code: 'VALIDATION_ERROR' },
      });
    }

    // Check schedule if dateTime changed
    if (dateTime !== undefined) {
      const unitForSchedule = await db
        .select({ buildingId: unitsTable.buildingId })
        .from(unitsTable)
        .where(eq(unitsTable.id, unitId || existing.unitId))
        .limit(1);

      if (unitForSchedule.length > 0) {
        const { buildingId } = unitForSchedule[0];
        const scheduleErr = await checkScheduleAvailability(checkEmployee, buildingId, checkDateTime);
        if (scheduleErr) {
          return res.status(409).json({
            success: false,
            error: { message: scheduleErr, code: 'SCHEDULE_CONFLICT' },
          });
        }
      }
    }

    // Check visit overlap if dateTime, duration, or employee changed
    if (dateTime !== undefined || durationMinutes !== undefined || employeeId !== undefined) {
      const conflict = await checkVisitConflict(checkEmployee, checkDateTime, checkDuration, id);
      if (conflict) {
        return res.status(409).json({
          success: false,
          error: {
            message: 'Employee already has a visit at this time',
            code: 'VISIT_CONFLICT',
            details: { conflictingVisitId: conflict.id, conflictingTime: conflict.dateTime },
          },
        });
      }
    }

    // Build update payload
    const updateData = { updatedAt: new Date() };
    if (unitId !== undefined) {updateData.unitId = unitId;}
    if (employeeId !== undefined) {updateData.employeeId = employeeId;}
    if (leadId !== undefined) {updateData.leadId = leadId;}
    if (dateTime !== undefined) {
      const parsed = new Date(dateTime);
      if (Number.isNaN(parsed.getTime())) {
        return res.status(400).json({
          success: false,
          error: { message: 'dateTime must be a valid ISO date string', code: 'VALIDATION_ERROR' },
        });
      }
      updateData.dateTime = parsed;
    }
    if (durationMinutes !== undefined) {updateData.durationMinutes = durationMinutes;}
    if (status !== undefined) {updateData.status = status;}
    if (tenantConfirmed !== undefined) {updateData.tenantConfirmed = tenantConfirmed;}
    if (employeeConfirmed !== undefined) {updateData.employeeConfirmed = employeeConfirmed;}
    if (morningOfSent !== undefined) {updateData.morningOfSent = morningOfSent;}
    if (outcome !== undefined) {updateData.outcome = outcome;}
    if (notes !== undefined) {updateData.notes = notes?.trim() || null;}
    if (isActive !== undefined) {updateData.isActive = isActive;}

    const [updated] = await db
      .update(visitsTable)
      .set(updateData)
      .where(eq(visitsTable.id, id))
      .returning();

    res.json({ success: true, data: updated, message: 'Visit updated successfully' });
  } catch (error) {
    logger.error('Error updating visit:', error);

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Referenced unit, employee, or lead not found', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Visit (soft delete) ───
exports.deleteVisit = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db
      .select()
      .from(visitsTable)
      .where(eq(visitsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Visit not found', code: 'VISIT_NOT_FOUND' },
      });
    }

    await db
      .update(visitsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(visitsTable.id, id));

    res.json({ success: true, data: null, message: 'Visit deleted successfully' });
  } catch (error) {
    logger.error('Error deleting visit:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_DELETE_FAILED' },
    });
  }
};

// ─── Update Visit Status ───
exports.updateVisitStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, outcome } = req.body;

    const validStatuses = ['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show'];

    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        error: {
          message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
          code: 'VALIDATION_ERROR',
        },
      });
    }

    const [existing] = await db
      .select()
      .from(visitsTable)
      .where(eq(visitsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Visit not found', code: 'VISIT_NOT_FOUND' },
      });
    }

    const updateData = { status, updatedAt: new Date() };

    // Auto-set confirmation flags based on status
    if (status === 'confirmed') {
      updateData.tenantConfirmed = true;
      updateData.employeeConfirmed = true;
    }

    if (outcome !== undefined) {
      const validOutcomes = ['interesse', 'pas_interesse', 'no_show', null];
      if (!validOutcomes.includes(outcome)) {
        return res.status(400).json({
          success: false,
          error: {
            message: 'Invalid outcome. Must be one of: interesse, pas_interesse, no_show, null',
            code: 'VALIDATION_ERROR',
          },
        });
      }
      updateData.outcome = outcome;
    }

    const [updated] = await db
      .update(visitsTable)
      .set(updateData)
      .where(eq(visitsTable.id, id))
      .returning();

    res.json({ success: true, data: updated, message: 'Visit status updated successfully' });
  } catch (error) {
    logger.error('Error updating visit status:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'VISIT_STATUS_UPDATE_FAILED' },
    });
  }
};
