const {
  getVisitsNeedingExpiry,
  expireVisits,
} = require('../src/services/sms.service');

jest.mock('../src/database/connection', () => {
  const mockUpdate = jest.fn().mockReturnValue({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockResolvedValue(undefined),
    }),
  });
  return {
    db: {
      select: jest.fn().mockReturnValue({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockResolvedValue([]),
        }),
      }),
      update: jest.fn().mockReturnValue(mockUpdate),
      insert: jest.fn().mockReturnValue({
        values: jest.fn().mockResolvedValue([{}]),
      }),
    },
  };
});

jest.mock('../src/database/schema', () => ({
  visitsTable: { id: 'id' },
  smsLogsTable: {},
  employeesTable: {},
  leadsTable: {},
  unitsTable: {},
  buildingsTable: {},
  usersTable: {},
  smsTemplatesTable: {},
  smsCampaignsTable: {},
  smsQueueTable: {},
  leasesTable: {},
}));

jest.mock('../src/services/twilio.service', () => ({
  sendSMS: jest.fn().mockResolvedValue({ success: true, sid: 'SM123' }),
  handleIncomingMessage: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { db } = require('../src/database/connection');

beforeEach(() => {
  jest.clearAllMocks();
});

describe('getVisitsNeedingExpiry', () => {
  it('returns visits that are scheduled, unconfirmed, and older than 24h', async () => {
    const visits = [
      { id: 'v1', status: 'scheduled', employeeConfirmed: false, createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000) },
      { id: 'v2', status: 'scheduled', employeeConfirmed: false, createdAt: new Date(Date.now() - 30 * 60 * 60 * 1000) },
    ];

    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(visits),
      }),
    });

    const result = await getVisitsNeedingExpiry();
    expect(result).toEqual(visits);
    expect(result).toHaveLength(2);
  });

  it('returns empty array when no visits need expiry', async () => {
    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue([]),
      }),
    });

    const result = await getVisitsNeedingExpiry();
    expect(result).toEqual([]);
    expect(result).toHaveLength(0);
  });

  it('returns empty array on database error', async () => {
    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockRejectedValue(new Error('Connection refused')),
      }),
    });

    const result = await getVisitsNeedingExpiry();
    expect(result).toEqual([]);
  });
});

describe('expireVisits', () => {
  it('cancels all visits needing expiry', async () => {
    const visits = [
      { id: 'v1', status: 'scheduled', employeeConfirmed: false, createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000) },
      { id: 'v2', status: 'scheduled', employeeConfirmed: false, createdAt: new Date(Date.now() - 48 * 60 * 60 * 1000) },
    ];

    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(visits),
      }),
    });

    const mockWhere = jest.fn().mockResolvedValue(undefined);
    db.update.mockReturnValue({
      set: jest.fn().mockReturnValue({ where: mockWhere }),
    });

    const result = await expireVisits();
    expect(result.expired).toBe(2);
    expect(db.update).toHaveBeenCalledTimes(2);
  });

  it('returns 0 expired when no visits need expiry', async () => {
    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue([]),
      }),
    });

    const result = await expireVisits();
    expect(result.expired).toBe(0);
  });

  it('returns expired count and error on failure', async () => {
    const visits = [
      { id: 'v1', status: 'scheduled', employeeConfirmed: false, createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000) },
    ];

    db.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(visits),
      }),
    });

    const mockWhere = jest.fn().mockRejectedValue(new Error('DB down'));
    db.update.mockReturnValue({
      set: jest.fn().mockReturnValue({ where: mockWhere }),
    });

    const result = await expireVisits();
    expect(result.expired).toBe(0);
    expect(result.error).toBe('DB down');
  });
});
