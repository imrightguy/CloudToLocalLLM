jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'sched-1', employeeId: 'emp-1', buildingId: 'bld-1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'sched-1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' }])),
      }),
    }),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  employeeSchedulesTable: { id: 'id', employeeId: 'employeeId', buildingId: 'buildingId', dayOfWeek: 'dayOfWeek', startTime: 'startTime', endTime: 'endTime', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt' },
}));

const scheduleController = require('../../src/controllers/schedule.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

// ═══════════════════════════════════════════════════════════════════
// createSchedule
// ═══════════════════════════════════════════════════════════════════
describe('createSchedule', () => {
  it('returns 400 when required fields missing', async () => {
    const res = mockRes();
    await scheduleController.createSchedule({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when dayOfWeek < 0', async () => {
    const res = mockRes();
    await scheduleController.createSchedule({ body: { employeeId: 'e', buildingId: 'b', dayOfWeek: -1, startTime: '09:00', endTime: '17:00' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when dayOfWeek > 6', async () => {
    const res = mockRes();
    await scheduleController.createSchedule({ body: { employeeId: 'e', buildingId: 'b', dayOfWeek: 7, startTime: '09:00', endTime: '17:00' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('creates schedule successfully', async () => {
    const res = mockRes();
    await scheduleController.createSchedule({ body: { employeeId: 'emp-1', buildingId: 'bld-1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'sched-1', dayOfWeek: 1 }),
    }));
  });

  it('returns 500 on DB error', async () => {
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(new Error('DB down')),
      }),
    });
    const res = mockRes();
    await scheduleController.createSchedule({ body: { employeeId: 'e', buildingId: 'b', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CREATION_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getSchedules
// ═══════════════════════════════════════════════════════════════════
describe('getSchedules', () => {
  it('returns schedules filtered by employeeId', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'sched-1', employeeId: 'emp-1' }]);
    const res = mockRes();
    await scheduleController.getSchedules({ query: { employeeId: 'emp-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [{ id: 'sched-1', employeeId: 'emp-1' }],
    }));
  });

  it('returns schedules filtered by buildingId and dayOfWeek', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([]);
    const res = mockRes();
    await scheduleController.getSchedules({ query: { buildingId: 'bld-1', dayOfWeek: '2' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('returns all active schedules with no filters', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'sched-1' }, { id: 'sched-2' }]);
    const res = mockRes();
    await scheduleController.getSchedules({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.arrayContaining([expect.objectContaining({ id: 'sched-1' })]),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await scheduleController.getSchedules({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_FETCH_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getScheduleById
// ═══════════════════════════════════════════════════════════════════
describe('getScheduleById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await scheduleController.getScheduleById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }),
    }));
  });

  it('returns schedule data', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'sched-1', dayOfWeek: 1 }]);
    const res = mockRes();
    await scheduleController.getScheduleById({ params: { id: 'sched-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'sched-1' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateSchedule
// ═══════════════════════════════════════════════════════════════════
describe('updateSchedule', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await scheduleController.updateSchedule({ params: { id: 'nonexistent' }, body: { startTime: '10:00' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }),
    }));
  });

  it('returns 400 when dayOfWeek is out of range', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'sched-1' }]);
    const res = mockRes();
    await scheduleController.updateSchedule({ params: { id: 'sched-1' }, body: { dayOfWeek: 10 } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('updates schedule successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'sched-1' }]);
    const res = mockRes();
    await scheduleController.updateSchedule({ params: { id: 'sched-1' }, body: { startTime: '10:00', endTime: '18:00' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'sched-1' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteSchedule
// ═══════════════════════════════════════════════════════════════════
describe('deleteSchedule', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await scheduleController.deleteSchedule({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }),
    }));
  });

  it('soft-deletes schedule', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'sched-1' }]);
    const res = mockRes();
    await scheduleController.deleteSchedule({ params: { id: 'sched-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Schedule deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// getEmployeeAvailability
// ═══════════════════════════════════════════════════════════════════
describe('getEmployeeAvailability', () => {
  it('returns 400 when employeeId missing', async () => {
    const res = mockRes();
    await scheduleController.getEmployeeAvailability({ params: { date: '2026-04-15' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when date is invalid', async () => {
    const res = mockRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'emp-1', date: 'not-a-date' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns availability for a Wednesday (dayOfWeek=2)', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'sched-1', dayOfWeek: 2, startTime: '09:00', endTime: '17:00' }]);
    const res = mockRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'emp-1', date: '2026-04-15' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        employeeId: 'emp-1',
        dayOfWeek: 2,
        schedules: [expect.objectContaining({ id: 'sched-1', dayOfWeek: 2 })],
      }),
    }));
  });

  it('converts Sunday (JS 0) to dayOfWeek 6', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([]);
    const res = mockRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'emp-1', date: '2026-04-12' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ dayOfWeek: 6 }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await scheduleController.getEmployeeAvailability({ params: { employeeId: 'emp-1', date: '2026-04-15' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});
