const { getPeriodStart } = require('../src/services/analytics.service');

describe('analytics.service', () => {
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
      mockDate(2026, 4, 8); // Wednesday April 8
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3); // April (0-indexed)
      expect(start.getDate()).toBe(6); // Monday April 6
    });

    it('returns Monday of current week for "week" period (Sunday)', () => {
      mockDate(2026, 4, 12); // Sunday April 12
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(6); // Monday April 6
    });

    it('returns Monday of current week for "week" period (Monday)', () => {
      mockDate(2026, 4, 6); // Monday April 6
      const start = getPeriodStart('week');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3);
      expect(start.getDate()).toBe(6); // Same Monday
    });

    it('returns first day of month for "month" period', () => {
      mockDate(2026, 4, 15); // April 15
      const start = getPeriodStart('month');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(3); // April
      expect(start.getDate()).toBe(1);
    });

    it('returns first day of year for "year" period', () => {
      mockDate(2026, 7, 20); // August 20
      const start = getPeriodStart('year');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0); // January
      expect(start.getDate()).toBe(1);
    });

    it('defaults to "week" for unknown period', () => {
      mockDate(2026, 4, 9); // Thursday
      const weekStart = getPeriodStart('week');
      const defaultStart = getPeriodStart();
      expect(defaultStart.getTime()).toBe(weekStart.getTime());
    });

    it('returns start of month for "month" at month boundary', () => {
      mockDate(2026, 1, 1); // January 1
      const start = getPeriodStart('month');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0);
      expect(start.getDate()).toBe(1);
    });

    it('returns start of year for "year" at year boundary', () => {
      mockDate(2026, 1, 1); // January 1
      const start = getPeriodStart('year');
      expect(start.getFullYear()).toBe(2026);
      expect(start.getMonth()).toBe(0);
      expect(start.getDate()).toBe(1);
    });
  });
});
