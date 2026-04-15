const { eq, and, asc } = require('drizzle-orm');
const { db } = require('../database/connection');
const { employeeSchedulesTable } = require('../database/schema');
const { child } = require('../utils/logger');

const log = child({ controller: 'schedule' });

// ─── Create Schedule ───
exports.createSchedule = async (req, res) => {
  try {
    const {
      employeeId, buildingId, dayOfWeek, startTime, endTime,
    } = req.body;

    if (!employeeId || !buildingId || dayOfWeek === undefined || !startTime || !endTime) {
      return res.status(400).json({
        success: false,
        error: { message: 'employeeId, buildingId, dayOfWeek, startTime, and endTime are required', code: 'VALIDATION_ERROR' },
      });
    }

    if (dayOfWeek < 0 || dayOfWeek > 6) {
      return res.status(400).json({
        success: false,
        error: { message: 'dayOfWeek must be between 0 (Monday) and 6 (Sunday)', code: 'VALIDATION_ERROR' },
      });
    }

    const [schedule] = await db.insert(employeeSchedulesTable).values({
      employeeId,
      buildingId,
      dayOfWeek,
      startTime,
      endTime,
      isActive: true,
    }).returning();

    res.status(201).json({
      success: true,
      data: schedule,
      message: 'Schedule created successfully',
    });
  } catch (error) {
    log.error('Error creating schedule', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'SCHEDULE_CREATION_FAILED' },
    });
  }
};

// ─── Get Schedules (filterable) ───
exports.getSchedules = async (req, res) => {
  try {
    const { employeeId, buildingId, dayOfWeek } = req.query;

    const conditions = [eq(employeeSchedulesTable.isActive, true)];
    if (employeeId) conditions.push(eq(employeeSchedulesTable.employeeId, employeeId));
    if (buildingId) conditions.push(eq(employeeSchedulesTable.buildingId, buildingId));
    if (dayOfWeek !== undefined) conditions.push(eq(employeeSchedulesTable.dayOfWeek, parseInt(dayOfWeek)));

    const schedules = await db.select()
      .from(employeeSchedulesTable)
      .where(and(...conditions))
      .orderBy(asc(employeeSchedulesTable.dayOfWeek), asc(employeeSchedulesTable.startTime));

    res.json({
      success: true,
      data: schedules,
      message: 'Schedules retrieved successfully',
    });
  } catch (error) {
    log.error('Error fetching schedules', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'SCHEDULE_FETCH_FAILED' },
    });
  }
};

// ─── Get Schedule By ID ───
exports.getScheduleById = async (req, res) => {
  try {
    const { id } = req.params;

    const [schedule] = await db.select()
      .from(employeeSchedulesTable)
      .where(eq(employeeSchedulesTable.id, id))
      .limit(1);

    if (!schedule) {
      return res.status(404).json({
        success: false,
        error: { message: 'Schedule not found', code: 'SCHEDULE_NOT_FOUND' },
      });
    }

    res.json({
      success: true,
      data: schedule,
      message: 'Schedule retrieved successfully',
    });
  } catch (error) {
    log.error('Error fetching schedule', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'SCHEDULE_FETCH_FAILED' },
    });
  }
};

// ─── Update Schedule ───
exports.updateSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      employeeId, buildingId, dayOfWeek, startTime, endTime, isActive,
    } = req.body;

    const [existing] = await db.select()
      .from(employeeSchedulesTable)
      .where(eq(employeeSchedulesTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Schedule not found', code: 'SCHEDULE_NOT_FOUND' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (employeeId !== undefined) updateData.employeeId = employeeId;
    if (buildingId !== undefined) updateData.buildingId = buildingId;
    if (dayOfWeek !== undefined) {
      if (dayOfWeek < 0 || dayOfWeek > 6) {
        return res.status(400).json({
          success: false,
          error: { message: 'dayOfWeek must be between 0 (Monday) and 6 (Sunday)', code: 'VALIDATION_ERROR' },
        });
      }
      updateData.dayOfWeek = dayOfWeek;
    }
    if (startTime !== undefined) updateData.startTime = startTime;
    if (endTime !== undefined) updateData.endTime = endTime;
    if (isActive !== undefined) updateData.isActive = isActive;

    const [updated] = await db.update(employeeSchedulesTable)
      .set(updateData)
      .where(eq(employeeSchedulesTable.id, id))
      .returning();

    res.json({
      success: true,
      data: updated,
      message: 'Schedule updated successfully',
    });
  } catch (error) {
    log.error('Error updating schedule', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'SCHEDULE_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Schedule (soft delete) ───
exports.deleteSchedule = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(employeeSchedulesTable)
      .where(eq(employeeSchedulesTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Schedule not found', code: 'SCHEDULE_NOT_FOUND' },
      });
    }

    await db.update(employeeSchedulesTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(employeeSchedulesTable.id, id));

    res.json({
      success: true,
      data: null,
      message: 'Schedule deleted successfully',
    });
  } catch (error) {
    log.error('Error deleting schedule', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'SCHEDULE_DELETE_FAILED' },
    });
  }
};

// ─── Get Employee Availability ───
exports.getEmployeeAvailability = async (req, res) => {
  try {
    const { employeeId, date } = req.params;

    if (!employeeId || !date) {
      return res.status(400).json({
        success: false,
        error: { message: 'employeeId and date are required', code: 'VALIDATION_ERROR' },
      });
    }

    // Validate date and extract day of week (0=Monday .. 6=Sunday)
    const parsedDate = new Date(date);
    if (Number.isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        error: { message: 'Invalid date format', code: 'VALIDATION_ERROR' },
      });
    }

    // Date string is YYYY-MM-DD (no time), so use UTC methods to avoid timezone shift.
    // getUTCDay() returns 0=Sunday, convert to 0=Monday schema.
    const jsDay = parsedDate.getUTCDay();
    const dayOfWeek = jsDay === 0 ? 6 : jsDay - 1;

    const schedules = await db.select()
      .from(employeeSchedulesTable)
      .where(
        and(
          eq(employeeSchedulesTable.employeeId, employeeId),
          eq(employeeSchedulesTable.dayOfWeek, dayOfWeek),
          eq(employeeSchedulesTable.isActive, true),
        ),
      )
      .orderBy(asc(employeeSchedulesTable.startTime));

    res.json({
      success: true,
      data: {
        employeeId,
        date,
        dayOfWeek,
        schedules,
      },
      message: 'Employee availability retrieved successfully',
    });
  } catch (error) {
    log.error('Error fetching employee availability', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'AVAILABILITY_FETCH_FAILED' },
    });
  }
};
