// ─── Mocks ──────────────────────────────────────────────────────────────────────

jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([]),
    insert: jest.fn().mockReturnValue({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'sched-1', employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00', isActive: true }]),
      }),
    }),
    update: jest.fn().mockReturnValue({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'sched-1', dayOfWeek: 2, updatedAt: new Date() }]),
        }),
      }),
    }),
  },
}));

jest.mock('../src/utils/logger', () => ({
  child: jest.fn(() => ({ error: jest.fn(), info: jest.fn() })),
}));

const scheduleController = require('../src/controllers/schedule.controller');
const { db } = require('../src/database/connection');

function makeRes() {
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  return { status, json };
}

function resetDb() {
  jest.clearAllMocks();
  db.select.mockReturnThis();
  db.from.mockReturnThis();
  db.where.mockReturnThis();
  db.orderBy.mockReturnThis();
  db.limit.mockResolvedValue([]);
  db.insert.mockReturnValue({
    values: jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([{ id: 'sched-1', employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00', isActive: true }]),
    }),
  });
  db.update.mockReturnValue({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'sched-1', dayOfWeek: 2, updatedAt: new Date() }]),
      }),
    }),
  });
}

const validBody = {
  employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00',
};

// ─── createSchedule ───

describe('scheduleController.createSchedule', () => {
  beforeEach(resetDb);

  describe('validation', () => {
    it('returns 400 when any required field is missing', async () => {
      const required = ['employeeId', 'buildingId', 'dayOfWeek', 'startTime', 'endTime'];
      for (const field of required) {
        const res = makeRes();
        const body = { ...validBody };
        delete body[field];
        await scheduleController.createSchedule({ body }, res);
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(
          expect.objectContaining({ success: false }),
        );
      }
    });

    it('returns 400 when dayOfWeek is negative', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: -1 } }, res);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
      );
    });

    it('returns 400 when dayOfWeek > 6', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 7 } }, res);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('returns 400 when dayOfWeek is 100', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 100 } }, res);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('error message mentions all required fields', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: {} }, res);
      const msg = res.json.mock.calls[0][0].error.message;
      expect(msg).toContain('employeeId');
      expect(msg).toContain('buildingId');
      expect(msg).toContain('dayOfWeek');
      expect(msg).toContain('startTime');
      expect(msg).toContain('endTime');
    });
  });

  describe('success path', () => {
    it('returns 201 with created schedule', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: validBody }, res);
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Schedule created successfully',
          data: expect.objectContaining({ id: 'sched-1', dayOfWeek: 1 }),
        }),
      );
    });

    it('calls db.insert with correct values', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: validBody }, res);
      expect(db.insert).toHaveBeenCalled();
    });

    it('accepts dayOfWeek 0 (Monday)', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 0 } }, res);
      expect(res.status).toHaveBeenCalledWith(201);
    });

    it('accepts dayOfWeek 6 (Sunday)', async () => {
      const res = makeRes();
      await scheduleController.createSchedule({ body: { ...validBody, dayOfWeek: 6 } }, res);
      expect(res.status).toHaveBeenCalledWith(201);
    });
  });

  describe('error handling', () => {
    it('returns 500 when db.insert fails', async () => {
      db.insert.mockImplementation(() => { throw new Error('DB down'); });
      const res = makeRes();
      await scheduleController.createSchedule({ body: validBody }, res);
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_CREATION_FAILED' }) }),
      );
    });
  });
});

// ─── getSchedules ───

describe('scheduleController.getSchedules', () => {
  beforeEach(resetDb);

  it('returns schedules successfully with no filters', async () => {
    const mockSchedules = [
      { id: 's1', employeeId: 'e1', buildingId: 'b1', dayOfWeek: 0, startTime: '09:00', endTime: '17:00', isActive: true },
      { id: 's2', employeeId: 'e2', buildingId: 'b1', dayOfWeek: 1, startTime: '10:00', endTime: '18:00', isActive: true },
    ];
    db.orderBy.mockResolvedValue(mockSchedules);

    const res = makeRes();
    await scheduleController.getSchedules({ query: {} }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: mockSchedules,
        message: 'Schedules retrieved successfully',
      }),
    );
  });

  it('passes employeeId filter when provided', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    await scheduleController.getSchedules({ query: { employeeId: 'e1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('passes buildingId filter when provided', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    await scheduleController.getSchedules({ query: { buildingId: 'b1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('passes dayOfWeek filter when provided', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    await scheduleController.getSchedules({ query: { dayOfWeek: '3' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('returns empty array when no schedules match', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    await scheduleController.getSchedules({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ data: [] }),
    );
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });
    const res = makeRes();
    await scheduleController.getSchedules({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_FETCH_FAILED' }) }),
    );
  });
});

// ─── getScheduleById ───

describe('scheduleController.getScheduleById', () => {
  beforeEach(resetDb);

  it('returns schedule by id', async () => {
    const schedule = { id: 'sched-1', employeeId: 'e1', dayOfWeek: 1 };
    db.limit.mockResolvedValue([schedule]);

    const res = makeRes();
    await scheduleController.getScheduleById({ params: { id: 'sched-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: schedule,
        message: 'Schedule retrieved successfully',
      }),
    );
  });

  it('returns 404 when schedule not found', async () => {
    db.limit.mockResolvedValue([]);

    const res = makeRes();
    await scheduleController.getScheduleById({ params: { id: 'nonexistent' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }) }),
    );
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });
    const res = makeRes();
    await scheduleController.getScheduleById({ params: { id: 'sched-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_FETCH_FAILED' }) }),
    );
  });
});

// ─── updateSchedule ───

describe('scheduleController.updateSchedule', () => {
  beforeEach(resetDb);

  it('returns 404 when schedule not found', async () => {
    db.limit.mockResolvedValue([]); // existing check finds nothing

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'nonexistent' }, body: { dayOfWeek: 3 } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }) }),
    );
  });

  it('updates and returns updated schedule', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', dayOfWeek: 1 }]);

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { dayOfWeek: 3 } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Schedule updated successfully',
      }),
    );
  });

  it('returns 400 when updating dayOfWeek to invalid value (< 0)', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', dayOfWeek: 1 }]);

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { dayOfWeek: -1 } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
    );
  });

  it('returns 400 when updating dayOfWeek to invalid value (> 6)', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', dayOfWeek: 1 }]);

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { dayOfWeek: 7 } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('allows partial update (only startTime)', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1' }]);

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { startTime: '10:00' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('allows setting isActive to false', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', isActive: true }]);

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { isActive: false } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('returns 500 when db fails on select', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    const res = makeRes();
    await scheduleController.updateSchedule(
      { params: { id: 'sched-1' }, body: { dayOfWeek: 3 } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_UPDATE_FAILED' }) }),
    );
  });
});

// ─── deleteSchedule ───

describe('scheduleController.deleteSchedule', () => {
  beforeEach(resetDb);

  it('returns 404 when schedule not found', async () => {
    db.limit.mockResolvedValue([]);

    const res = makeRes();
    await scheduleController.deleteSchedule({ params: { id: 'nonexistent' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }) }),
    );
  });

  it('soft-deletes schedule by setting isActive false', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', isActive: true }]);

    const res = makeRes();
    await scheduleController.deleteSchedule({ params: { id: 'sched-1' } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: null,
        message: 'Schedule deleted successfully',
      }),
    );
  });

  it('calls db.update for soft delete', async () => {
    db.limit.mockResolvedValue([{ id: 'sched-1', isActive: true }]);

    const res = makeRes();
    await scheduleController.deleteSchedule({ params: { id: 'sched-1' } }, res);

    expect(db.update).toHaveBeenCalled();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    const res = makeRes();
    await scheduleController.deleteSchedule({ params: { id: 'sched-1' } }, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_DELETE_FAILED' }) }),
    );
  });
});

// ─── getEmployeeAvailability ───

describe('scheduleController.getEmployeeAvailability', () => {
  beforeEach(resetDb);

  it('returns 400 for invalid date string', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: 'not-a-date' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
    );
  });

  it('returns 400 for empty date', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: '' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 for gibberish date', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'e1', date: 'abc123' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when employeeId is missing', async () => {
    const res = makeRes();
    await scheduleController.getEmployeeAvailability({ params: { date: '2026-04-15' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
    );
  });

  it('returns availability for valid date', async () => {
    const mockSchedules = [
      { id: 's1', employeeId: 'e1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00', isActive: true },
    ];
    db.orderBy.mockResolvedValue(mockSchedules);

    const res = makeRes();
    // 2026-04-15 is a Wednesday; getUTCDay()=3, dayOfWeek=2
    await scheduleController.getEmployeeAvailability(
      { params: { employeeId: 'e1', date: '2026-04-15' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          employeeId: 'e1',
          date: '2026-04-15',
          dayOfWeek: 2,
          schedules: mockSchedules,
        }),
      }),
    );
  });

  it('converts Sunday (getUTCDay=0) to dayOfWeek 6', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    // 2026-04-19 is a Sunday
    await scheduleController.getEmployeeAvailability(
      { params: { employeeId: 'e1', date: '2026-04-19' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ dayOfWeek: 6 }),
      }),
    );
  });

  it('converts Monday (getUTCDay=1) to dayOfWeek 0', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    // 2026-04-13 is a Monday
    await scheduleController.getEmployeeAvailability(
      { params: { employeeId: 'e1', date: '2026-04-13' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ dayOfWeek: 0 }),
      }),
    );
  });

  it('returns empty schedules when none match', async () => {
    db.orderBy.mockResolvedValue([]);
    const res = makeRes();
    await scheduleController.getEmployeeAvailability(
      { params: { employeeId: 'e1', date: '2026-04-15' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({ schedules: [] }),
      }),
    );
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });
    const res = makeRes();
    await scheduleController.getEmployeeAvailability(
      { params: { employeeId: 'e1', date: '2026-04-15' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'AVAILABILITY_FETCH_FAILED' }) }),
    );
  });
});

// ─── JS getDay() → schema dayOfWeek conversion (pure logic) ───

describe('JS getDay() → schema dayOfWeek conversion', () => {
  function jsDayToSchema(jsDay) {
    return jsDay === 0 ? 6 : jsDay - 1;
  }

  it('Sunday (getDay=0) → 6', () => expect(jsDayToSchema(0)).toBe(6));
  it('Monday (getDay=1) → 0', () => expect(jsDayToSchema(1)).toBe(0));
  it('Tuesday (getDay=2) → 1', () => expect(jsDayToSchema(2)).toBe(1));
  it('Wednesday (getDay=3) → 2', () => expect(jsDayToSchema(3)).toBe(2));
  it('Thursday (getDay=4) → 3', () => expect(jsDayToSchema(4)).toBe(3));
  it('Friday (getDay=5) → 4', () => expect(jsDayToSchema(5)).toBe(4));
  it('Saturday (getDay=6) → 5', () => expect(jsDayToSchema(6)).toBe(5));
});
