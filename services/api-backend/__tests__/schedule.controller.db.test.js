jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

let mockInsertValues;
let mockInsertReturning;
let mockUpdateSet;
let mockUpdateReturning;

const createSelectChain = (finalResult) => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockResolvedValue(finalResult);
  chain.then = jest.fn((resolve) => resolve(finalResult));
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => {
    const chain = {};
    chain.values = jest.fn().mockReturnValue({
      returning: jest.fn(() => {
        mockInsertValues = chain.values.mock.calls[0][0];
        return Promise.resolve(mockInsertReturning);
      }),
    });
    return chain;
  }),
  update: jest.fn(() => {
    const chain = {};
    const whereChain = {};
    whereChain.returning = jest.fn(() => {
      mockUpdateSet = chain.set.mock.calls[0][0];
      return Promise.resolve(mockUpdateReturning);
    });
    whereChain.then = jest.fn((resolve) => {
      mockUpdateSet = chain.set.mock.calls[0][0];
      resolve(undefined);
    });
    chain.set = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue(whereChain),
    });
    return chain;
  }),
};

jest.mock('../src/database/connection', () => ({ db: mockDb }));

jest.mock('../src/database/schema', () => ({
  employeeSchedulesTable: {
    id: 'id',
    employeeId: 'employeeId',
    buildingId: 'buildingId',
    dayOfWeek: 'dayOfWeek',
    startTime: 'startTime',
    endTime: 'endTime',
    isActive: 'isActive',
  },
}));

const scheduleController = require('../src/controllers/schedule.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  mockInsertReturning = [{ id: 's1', employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00', isActive: true }];
  mockUpdateReturning = [{ id: 's1', employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00', isActive: true }];
  mockInsertValues = null;
  mockUpdateSet = null;
  selectChain = createSelectChain([]);
});

describe('scheduleController — DB paths', () => {
  describe('createSchedule — success', () => {
    it('returns 201 with created schedule', async () => {
      const res = mockRes();
      await scheduleController.createSchedule({
        body: { employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' },
      }, res);
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: mockInsertReturning[0] }),
      );
    });

    it('passes isActive: true to insert', async () => {
      const res = mockRes();
      await scheduleController.createSchedule({
        body: { employeeId: 'e1', buildingId: 'b1', dayOfWeek: 0, startTime: '08:00', endTime: '16:00' },
      }, res);
      expect(mockInsertValues.isActive).toBe(true);
    });

    it('accepts dayOfWeek boundary values 0 and 6', async () => {
      for (const dow of [0, 6]) {
        const res = mockRes();
        await scheduleController.createSchedule({
          body: { employeeId: 'e1', buildingId: 'b1', dayOfWeek: dow, startTime: '09:00', endTime: '17:00' },
        }, res);
        expect(res.status).toHaveBeenCalledWith(201);
      }
    });
  });

  describe('createSchedule — DB error', () => {
    it('returns 500 on database failure', async () => {
      mockDb.insert.mockImplementationOnce(() => ({
        values: jest.fn().mockReturnValue({
          returning: jest.fn(() => Promise.reject(new Error('DB down'))),
        }),
      }));
      const res = mockRes();
      await scheduleController.createSchedule({
        body: { employeeId: 'e1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' },
      }, res);
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, error: expect.objectContaining({ code: 'SCHEDULE_CREATION_FAILED' }) }),
      );
    });
  });

  describe('getSchedules', () => {
    it('returns all active schedules when no filters', async () => {
      selectChain = createSelectChain([{ id: 's1' }, { id: 's2' }]);
      const res = mockRes();
      await scheduleController.getSchedules({ query: {} }, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: [{ id: 's1' }, { id: 's2' }] }),
      );
    });

    it('returns empty array when no schedules match', async () => {
      selectChain = createSelectChain([]);
      const res = mockRes();
      await scheduleController.getSchedules({ query: { employeeId: 'e1' } }, res);
      expect(selectChain.where).toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: [] }),
      );
    });

    it('passes filter conditions for buildingId and dayOfWeek', async () => {
      selectChain = createSelectChain([]);
      const res = mockRes();
      await scheduleController.getSchedules({ query: { buildingId: 'b1', dayOfWeek: '3' } }, res);
      expect(selectChain.where).toHaveBeenCalled();
    });

    it('returns 500 on DB error', async () => {
      selectChain = createSelectChain([]);
      selectChain.orderBy.mockImplementationOnce(() => { throw new Error('DB error'); });
      const res = mockRes();
      await scheduleController.getSchedules({ query: {} }, res);
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.objectContaining({ code: 'SCHEDULE_FETCH_FAILED' }) }),
      );
    });
  });

  describe('getScheduleById', () => {
    it('returns schedule when found', async () => {
      selectChain = createSelectChain([{ id: 's1', dayOfWeek: 2 }]);
      const res = mockRes();
      await scheduleController.getScheduleById({ params: { id: 's1' } }, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: { id: 's1', dayOfWeek: 2 } }),
      );
    });

    it('returns 404 when not found', async () => {
      selectChain = createSelectChain([]);
      const res = mockRes();
      await scheduleController.getScheduleById({ params: { id: 'nonexistent' } }, res);
      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.objectContaining({ code: 'SCHEDULE_NOT_FOUND' }) }),
      );
    });

    it('returns 500 on DB error', async () => {
      selectChain = createSelectChain([]);
      selectChain.limit.mockRejectedValueOnce(new Error('fail'));
      const res = mockRes();
      await scheduleController.getScheduleById({ params: { id: 's1' } }, res);
      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('updateSchedule', () => {
    it('returns updated schedule', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      mockUpdateReturning = [{ id: 's1', startTime: '10:00' }];
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { startTime: '10:00' },
      }, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: mockUpdateReturning[0] }),
      );
    });

    it('returns 404 when schedule not found', async () => {
      selectChain = createSelectChain([]);
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 'nonexistent' },
        body: { startTime: '10:00' },
      }, res);
      expect(res.status).toHaveBeenCalledWith(404);
    });

    it('returns 400 for invalid dayOfWeek in update', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { dayOfWeek: -1 },
      }, res);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.objectContaining({ code: 'VALIDATION_ERROR' }) }),
      );
    });

    it('returns 400 for dayOfWeek > 6 in update', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { dayOfWeek: 9 },
      }, res);
      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('allows partial update (isActive only)', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      mockUpdateReturning = [{ id: 's1', isActive: false }];
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { isActive: false },
      }, res);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('sets updatedAt in update', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { endTime: '18:00' },
      }, res);
      expect(mockUpdateSet.updatedAt).toBeInstanceOf(Date);
    });

    it('returns 500 on DB error during update', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      mockDb.update.mockImplementationOnce(() => ({
        set: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            returning: jest.fn(() => Promise.reject(new Error('fail'))),
          }),
        }),
      }));
      const res = mockRes();
      await scheduleController.updateSchedule({
        params: { id: 's1' },
        body: { startTime: '10:00' },
      }, res);
      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('deleteSchedule', () => {
    it('soft-deletes by setting isActive: false', async () => {
      selectChain = createSelectChain([{ id: 's1' }]);
      const res = mockRes();
      await scheduleController.deleteSchedule({ params: { id: 's1' } }, res);
      expect(mockUpdateSet.isActive).toBe(false);
      expect(mockUpdateSet.updatedAt).toBeInstanceOf(Date);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: null }),
      );
    });

    it('returns 404 when schedule not found', async () => {
      selectChain = createSelectChain([]);
      const res = mockRes();
      await scheduleController.deleteSchedule({ params: { id: 'nonexistent' } }, res);
      expect(res.status).toHaveBeenCalledWith(404);
    });

    it('returns 500 on DB error', async () => {
      selectChain = createSelectChain([]);
      selectChain.limit.mockRejectedValueOnce(new Error('fail'));
      const res = mockRes();
      await scheduleController.deleteSchedule({ params: { id: 's1' } }, res);
      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('getEmployeeAvailability — success', () => {
    it('returns schedules and correct dayOfWeek for a given date', async () => {
      const result = [{ id: 's1', startTime: '09:00' }];
      const chain = createSelectChain(result);
      selectChain = chain;

      const res = mockRes();
      await scheduleController.getEmployeeAvailability({
        params: { employeeId: 'e1', date: '2025-04-14' },
      }, res);

      const callArg = res.json.mock.calls[0][0];
      expect(callArg.success).toBe(true);
      expect(callArg.data.employeeId).toBe('e1');
      expect(callArg.data.date).toBe('2025-04-14');
      expect(callArg.data.schedules).toEqual(result);
      expect(typeof callArg.data.dayOfWeek).toBe('number');
      expect(callArg.data.dayOfWeek).toBeGreaterThanOrEqual(0);
      expect(callArg.data.dayOfWeek).toBeLessThanOrEqual(6);
    });

    it('computes dayOfWeek using UTC day conversion (YYYY-MM-DD is UTC)', async () => {
      selectChain = createSelectChain([]);

      const res = mockRes();
      await scheduleController.getEmployeeAvailability({
        params: { employeeId: 'e1', date: '2025-04-14' },
      }, res);

      const dayOfWeek = res.json.mock.calls[0][0].data.dayOfWeek;
      // Controller uses getUTCDay() because the date string is YYYY-MM-DD (UTC midnight)
      const jsDay = new Date('2025-04-14').getUTCDay();
      const expected = jsDay === 0 ? 6 : jsDay - 1;
      expect(dayOfWeek).toBe(expected);
    });

    it('returns 500 on DB error', async () => {
      const chain = createSelectChain([]);
      chain.orderBy.mockRejectedValueOnce(new Error('fail'));
      selectChain = chain;

      const res = mockRes();
      await scheduleController.getEmployeeAvailability({
        params: { employeeId: 'e1', date: '2025-04-14' },
      }, res);
      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.objectContaining({ code: 'AVAILABILITY_FETCH_FAILED' }) }),
      );
    });
  });
});
