const { getPeriodStart } = require('../src/services/analytics.service');

jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    and: jest.fn().mockReturnThis(),
    or: jest.fn().mockReturnThis(),
    innerJoin: jest.fn().mockReturnThis(),
    leftJoin: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    as: jest.fn(),
  },
}));

jest.mock('../src/utils/logger', () => ({
  error: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
}));

jest.mock('../src/utils/cache', () => {
  const store = new Map();
  return {
    cache: {
      get: jest.fn((key) => store.get(key)),
      set: jest.fn((key, value) => { store.set(key, value); }),
      _store: store,
    },
  };
});

jest.mock('../src/constants/lead-stages', () => ({
  VALID_LEAD_STAGES: ['nouveau', 'contacte', 'interesse', 'signe', 'bailSigne'],
}));

const { db } = require('../src/database/connection');
const { cache } = require('../src/utils/cache');

function createChain(resolveWith, shouldReject = false) {
  const chain = {};
  const methods = [
    'select', 'from', 'where', 'and', 'or',
    'innerJoin', 'leftJoin', 'groupBy', 'orderBy', 'limit',
  ];
  methods.forEach((method) => {
    chain[method] = jest.fn().mockReturnValue(chain);
  });
  chain.then = function (onFulfilled, onRejected) {
    if (shouldReject) {
      return Promise.reject(resolveWith).then(onFulfilled, onRejected);
    }
    return Promise.resolve(resolveWith).then(onFulfilled, onRejected);
  };
  chain.catch = function (onRejected) {
    if (shouldReject) {
      return Promise.reject(resolveWith).catch(onRejected);
    }
    return Promise.resolve(resolveWith).catch(onRejected);
  };
  return chain;
}

describe('analytics.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cache._store.clear();
    db.select.mockReset().mockReturnThis();
    db.from.mockReset().mockReturnThis();
    db.where.mockReset().mockReturnThis();
    db.and.mockReset().mockReturnThis();
    db.or.mockReset().mockReturnThis();
    db.innerJoin.mockReset().mockReturnThis();
    db.leftJoin.mockReset().mockReturnThis();
    db.groupBy.mockReset().mockReturnThis();
    db.orderBy.mockReset().mockReturnThis();
    db.limit.mockReset().mockReturnThis();
  });

  // ─── getPeriodStart ─────────────────────────────────────────────────────────

  describe('getPeriodStart', () => {
    let originalDate;

    beforeEach(() => {
      originalDate = global.Date;
    });

    afterEach(() => {
      global.Date = originalDate;
    });

    function mockDate(year, month, day) {
      const FixedDate = class extends Date {
        constructor(...args) {
          if (args.length === 0) {
            super(year, month - 1, day);
          } else {
            super(...args);
          }
        }
      };
      FixedDate.now = () => new FixedDate().getTime();
      global.Date = FixedDate;
    }

    it('returns Monday of current week for "week" period (Wednesday)', () => {
      mockDate(2026, 4, 8);
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(6);
    });

    it('returns Monday of current week for "week" period (Sunday)', () => {
      mockDate(2026, 4, 12);
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(6);
    });

    it('returns Monday of current week for "week" period (Monday)', () => {
      mockDate(2026, 4, 6);
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(6);
    });

    it('returns first day of month for "month" period', () => {
      mockDate(2026, 4, 15);
      const start = getPeriodStart('month');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(1);
    });

    it('returns first day of year for "year" period', () => {
      mockDate(2026, 7, 20);
      const start = getPeriodStart('year');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0);
      expect(start.getDate()).toBe(1);
    });

    it('defaults to "week" for unknown period', () => {
      mockDate(2026, 4, 9);
      const weekStart = getPeriodStart('week');
      const defaultStart = getPeriodStart();
      expect(defaultStart.getTime()).toBe(weekStart.getTime());
    });

    it('returns start of month for "month" at month boundary', () => {
      mockDate(2026, 1, 1);
      const start = getPeriodStart('month');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0);
      expect(start.getDate()).toBe(1);
    });

    it('returns start of year for "year" at year boundary', () => {
      mockDate(2026, 1, 1);
      const start = getPeriodStart('year');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0);
      expect(start.getDate()).toBe(1);
    });
  });

  // ─── getOccupancyTrend ──────────────────────────────────────────────────────

  describe('getOccupancyTrend', () => {
    let getOccupancyTrend;

    beforeEach(() => {
      jest.isolateModules(() => {
        ({ getOccupancyTrend } = require('../src/services/analytics.service'));
      });
    });

    it('returns occupancy data grouped by units.status for all buildings', async () => {
      const rows = [
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', status: 'occupied', count: '16' },
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', status: 'vacant', count: '4' },
        { buildingId: 'bldg-2', buildingName: '5678 Blvd René-Lévesque', status: 'occupied', count: '10' },
      ];
      db.select.mockReturnValue(createChain(rows));

      const result = await getOccupancyTrend(null);

      expect(result).toEqual([
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', totalUnits: 20, occupiedUnits: 16, vacantUnits: 4, maintenanceUnits: 0, occupancyRate: 0.8 },
        { buildingId: 'bldg-2', buildingName: '5678 Blvd René-Lévesque', totalUnits: 10, occupiedUnits: 10, vacantUnits: 0, maintenanceUnits: 0, occupancyRate: 1 },
      ]);
      expect(db.select).toHaveBeenCalledTimes(1);
    });

    it('filters by buildingId when provided', async () => {
      const rows = [
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', status: 'occupied', count: '16' },
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', status: 'maintenance', count: '2' },
        { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', status: 'vacant', count: '2' },
      ];
      db.select.mockReturnValue(createChain(rows));

      const result = await getOccupancyTrend('bldg-1');

      expect(result).toHaveLength(1);
      expect(result[0].buildingId).toBe('bldg-1');
      expect(result[0].maintenanceUnits).toBe(2);
    });

    it('handles zero total units gracefully', async () => {
      db.select.mockReturnValue(createChain([]));

      const result = await getOccupancyTrend(null);

      expect(result).toEqual([]);
    });

    it('returns empty array when no buildings found', async () => {
      db.select.mockReturnValue(createChain([]));

      const result = await getOccupancyTrend(null);

      expect(result).toEqual([]);
    });

    it('caches results and returns cached on second call', async () => {
      const rows = [
        { buildingId: 'bldg-1', buildingName: 'Test', status: 'occupied', count: '5' },
      ];
      db.select.mockReturnValue(createChain(rows));

      const result1 = await getOccupancyTrend(null);
      const result2 = await getOccupancyTrend(null);

      expect(result1).toEqual(result2);
      expect(db.select).toHaveBeenCalledTimes(1);
      expect(cache.set).toHaveBeenCalled();
      expect(cache.get).toHaveBeenCalled();
    });

    it('throws and logs on database error', async () => {
      const logger = require('../src/utils/logger');
      db.select.mockReturnValue(createChain(new Error('DB connection lost'), true));

      await expect(getOccupancyTrend(null)).rejects.toThrow('DB connection lost');
      expect(logger.error).toHaveBeenCalled();
    });
  });

  // ─── getRevenueTrend ────────────────────────────────────────────────────────

  describe('getRevenueTrend', () => {
    let getRevenueTrend;

    beforeEach(() => {
      jest.isolateModules(() => {
        ({ getRevenueTrend } = require('../src/services/analytics.service'));
      });
    });

    it('returns revenue data and totals with default params', async () => {
      const data = [
        { date: '2026-01-01', value: '15000', buildingId: 'bldg-1', buildingName: '1234 Rue' },
      ];
      const totals = [
        { date: '2026-01-01', value: '30000' },
      ];

      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        return createChain(callCount === 1 ? data : totals);
      });

      const result = await getRevenueTrend('12m', null, 'month');

      expect(result.data).toEqual([
        { date: '2026-01-01', value: 15000, buildingId: 'bldg-1', buildingName: '1234 Rue' },
      ]);
      expect(result.totals).toEqual([
        { date: '2026-01-01', value: 30000 },
      ]);
      expect(db.select).toHaveBeenCalledTimes(2);
    });

    it('passes correct period for 30d', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      await getRevenueTrend('30d', null, 'day');
      expect(db.select).toHaveBeenCalledTimes(2);
    });

    it('passes correct period for 90d', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      await getRevenueTrend('90d', 'bldg-1', 'week');
      expect(db.select).toHaveBeenCalledTimes(2);
    });

    it('handles empty results gracefully', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      const result = await getRevenueTrend('30d', null, 'day');

      expect(result.data).toEqual([]);
      expect(result.totals).toEqual([]);
    });

    it('throws on invalid period', async () => {
      await expect(getRevenueTrend('invalid')).rejects.toThrow('Invalid period');
    });

    it('throws on invalid granularity', async () => {
      await expect(getRevenueTrend('30d', null, 'year')).rejects.toThrow('Invalid granularity');
    });

    it('caches results and returns cached on second call', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      await getRevenueTrend('12m', null, 'month');
      await getRevenueTrend('12m', null, 'month');

      expect(db.select).toHaveBeenCalledTimes(2);
      expect(cache.set).toHaveBeenCalled();
    });

    it('throws and logs on database error', async () => {
      const logger = require('../src/utils/logger');
      db.select.mockReturnValue(createChain(new Error('Query failed'), true));

      await expect(getRevenueTrend('12m')).rejects.toThrow('Query failed');
      expect(logger.error).toHaveBeenCalled();
    });
  });

  // ─── getLeadFunnel ──────────────────────────────────────────────────────────

  describe('getLeadFunnel', () => {
    let getLeadFunnel;

    beforeEach(() => {
      jest.isolateModules(() => {
        ({ getLeadFunnel } = require('../src/services/analytics.service'));
      });
    });

    it('returns stages, conversionRate (signed stages), and timeline', async () => {
      const stageRows = [
        { stage: 'nouveau', count: '10' },
        { stage: 'contacte', count: '7' },
        { stage: 'signe', count: '3' },
      ];
      const timelineRows = [
        { date: '2026-03-17', stage: 'nouveau', count: '3' },
        { date: '2026-03-17', stage: 'contacte', count: '2' },
      ];

      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        return createChain(callCount === 1 ? stageRows : timelineRows);
      });

      const result = await getLeadFunnel('90d', null, 'week');

      expect(result.stages).toEqual([
        { stage: 'nouveau', count: 10 },
        { stage: 'contacte', count: 7 },
        { stage: 'signe', count: 3 },
      ]);
      expect(result.conversionRate).toBe('15.0%');
      expect(result.timeline).toEqual([
        { date: '2026-03-17', stage: 'nouveau', count: 3 },
        { date: '2026-03-17', stage: 'contacte', count: 2 },
      ]);
    });

    it('calculates conversion rate from signed stages (signe + bailSigne)', async () => {
      const stageRows = [
        { stage: 'nouveau', count: '77' },
        { stage: 'signe', count: '15' },
        { stage: 'bailSigne', count: '8' },
      ];

      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        return createChain(callCount === 1 ? stageRows : []);
      });

      const result = await getLeadFunnel('30d');

      expect(result.conversionRate).toBe('23.0%');
    });

    it('returns 0% conversion rate when no signed leads', async () => {
      const stageRows = [
        { stage: 'nouveau', count: '50' },
        { stage: 'contacte', count: '10' },
      ];

      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        return createChain(callCount === 1 ? stageRows : []);
      });

      const result = await getLeadFunnel('30d');

      expect(result.conversionRate).toBe('0.0%');
    });

    it('returns 0% conversion rate when no leads', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      const result = await getLeadFunnel('30d');

      expect(result.conversionRate).toBe('0.0%');
      expect(result.stages).toEqual([]);
    });

    it('filters by buildingId', async () => {
      const stageRows = [
        { stage: 'signe', count: '5' },
      ];

      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        return createChain(callCount === 1 ? stageRows : []);
      });

      await getLeadFunnel('90d', 'bldg-1', 'day');
      expect(db.select).toHaveBeenCalledTimes(2);
    });

    it('throws on invalid period', async () => {
      await expect(getLeadFunnel('invalid')).rejects.toThrow('Invalid period');
    });

    it('throws on invalid granularity', async () => {
      await expect(getLeadFunnel('30d', null, 'hour')).rejects.toThrow('Invalid granularity');
    });

    it('caches results and returns cached on second call', async () => {
      db.select.mockImplementation(() => {
        return createChain([]);
      });

      await getLeadFunnel('90d', null, 'week');
      await getLeadFunnel('90d', null, 'week');

      expect(db.select).toHaveBeenCalledTimes(2);
      expect(cache.set).toHaveBeenCalled();
    });

    it('throws and logs on database error', async () => {
      const logger = require('../src/utils/logger');
      db.select.mockReturnValue(createChain(new Error('DB error'), true));

      await expect(getLeadFunnel('90d')).rejects.toThrow('DB error');
      expect(logger.error).toHaveBeenCalled();
    });
  });

  // ─── getVisitMetrics ────────────────────────────────────────────────────────

  describe('getVisitMetrics', () => {
    let getVisitMetrics;

    beforeEach(() => {
      jest.isolateModules(() => {
        ({ getVisitMetrics } = require('../src/services/analytics.service'));
      });
    });

    it('returns completionRate, noShowRate, totalVisits, avgTimeToLease, and timeline', async () => {
      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        if (callCount === 1) return createChain([{ total: '25' }]);
        if (callCount === 2) return createChain([{ completed: '18' }]);
        if (callCount === 3) return createChain([{ noShow: '3' }]);
        if (callCount === 4) return createChain([{ cancelled: '4' }]);
        if (callCount === 5) return createChain([{ avgDays: '12.5' }]);
        return createChain([
          { date: '2026-03-17', completed: '5', cancelled: '1', noShow: '1' },
        ]);
      });

      const result = await getVisitMetrics('30d', null, 'week');

      expect(result.completionRate).toBe('72.0%');
      expect(result.noShowRate).toBe('12.0%');
      expect(result.totalVisits).toBe(25);
      expect(result.avgTimeToLease).toBe(12.5);
      expect(result.timeline).toEqual([
        { date: '2026-03-17', completed: 5, cancelled: 1, noShow: 1 },
      ]);
      expect(db.select).toHaveBeenCalledTimes(6);
    });

    it('returns 0% rates and null avgTimeToLease when no visits', async () => {
      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        if (callCount <= 4) return createChain([{ total: '0' }]);
        if (callCount === 5) return createChain([{ avgDays: null }]);
        return createChain([]);
      });

      const result = await getVisitMetrics('30d');

      expect(result.completionRate).toBe('0.0%');
      expect(result.noShowRate).toBe('0.0%');
      expect(result.totalVisits).toBe(0);
      expect(result.avgTimeToLease).toBeNull();
      expect(result.timeline).toEqual([]);
    });

    it('calculates rates correctly with different granularity', async () => {
      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        if (callCount === 1) return createChain([{ total: '100' }]);
        if (callCount === 2) return createChain([{ completed: '50' }]);
        if (callCount === 3) return createChain([{ noShow: '25' }]);
        if (callCount === 4) return createChain([{ cancelled: '25' }]);
        if (callCount === 5) return createChain([{ avgDays: '7.3' }]);
        return createChain([]);
      });

      const result = await getVisitMetrics('90d', 'bldg-1', 'day');

      expect(result.completionRate).toBe('50.0%');
      expect(result.noShowRate).toBe('25.0%');
      expect(result.avgTimeToLease).toBe(7.3);
      expect(db.select).toHaveBeenCalledTimes(6);
    });

    it('handles 12m period', async () => {
      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        if (callCount <= 4) return createChain([{ total: '0' }]);
        if (callCount === 5) return createChain([{ avgDays: null }]);
        return createChain([]);
      });

      await getVisitMetrics('12m', null, 'month');
      expect(db.select).toHaveBeenCalledTimes(6);
    });

    it('throws on invalid period', async () => {
      await expect(getVisitMetrics('invalid')).rejects.toThrow('Invalid period');
    });

    it('throws on invalid granularity', async () => {
      await expect(getVisitMetrics('30d', null, 'quarter')).rejects.toThrow('Invalid granularity');
    });

    it('caches results and returns cached on second call', async () => {
      let callCount = 0;
      db.select.mockImplementation(() => {
        callCount++;
        if (callCount <= 4) return createChain([{ total: '0' }]);
        if (callCount === 5) return createChain([{ avgDays: null }]);
        return createChain([]);
      });

      await getVisitMetrics('30d', null, 'week');
      await getVisitMetrics('30d', null, 'week');

      expect(db.select).toHaveBeenCalledTimes(6);
      expect(cache.set).toHaveBeenCalled();
    });

    it('throws and logs on database error', async () => {
      const logger = require('../src/utils/logger');
      db.select.mockReturnValue(createChain(new Error('Connection refused'), true));

      await expect(getVisitMetrics('30d')).rejects.toThrow('Connection refused');
      expect(logger.error).toHaveBeenCalled();
    });
  });
});
