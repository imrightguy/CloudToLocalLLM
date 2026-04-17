jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([]),
  },
}));

jest.mock('../src/services/notification.service', () => ({
  sendEmail: jest.fn(),
  initMailer: jest.fn(),
}));

jest.mock('../src/services/analytics.service', () => ({
  getWeeklySummary: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const emailService = require('../src/services/email.service');
const notificationService = require('../src/services/notification.service');
const analyticsService = require('../src/services/analytics.service');
const { db } = require('../src/database/connection');

function setupDbQueries(queries) {
  let queryIdx = 0;

  db.where.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'where') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return db;
  });

  db.limit.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'limit') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return Promise.resolve([]);
  });
}

describe('email.service', () => {
  let originalEnv;

  beforeEach(() => {
    originalEnv = { ...process.env };
    jest.clearAllMocks();
    db.select.mockReturnThis();
    db.from.mockReturnThis();
    db.where.mockReturnThis();
    db.limit.mockResolvedValue([]);
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  describe('getUserPreferences', () => {
    it('returns preferences when they exist', async () => {
      const prefs = { userId: 'user-1', emailNotifications: true, weeklyDigest: true };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const result = await emailService.getUserPreferences('user-1');

      expect(result).toEqual(prefs);
    });

    it('returns null when no preferences exist', async () => {
      setupDbQueries([{ via: 'limit', returns: [] }]);

      const result = await emailService.getUserPreferences('user-1');

      expect(result).toBeNull();
    });
  });

  describe('shouldSendEmail', () => {
    it('returns false when SMTP_HOST is not set', async () => {
      delete process.env.SMTP_HOST;

      const result = await emailService.shouldSendEmail('user-1');

      expect(result).toBe(false);
    });

    it('returns true when no preferences exist (default allow)', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      setupDbQueries([{ via: 'limit', returns: [] }]);

      const result = await emailService.shouldSendEmail('user-1');

      expect(result).toBe(true);
    });

    it('returns false when emailNotifications is disabled', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: false, quietHoursEnabled: false };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const result = await emailService.shouldSendEmail('user-1');

      expect(result).toBe(false);
    });

    it('returns true when emailNotifications is enabled', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: true, quietHoursEnabled: false };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const result = await emailService.shouldSendEmail('user-1');

      expect(result).toBe(true);
    });

    it('respects quiet hours (simple case)', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = {
        userId: 'user-1',
        emailNotifications: true,
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
      };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const hour = new Date();
      hour.setHours(0, 0, 0, 0);
      const originalDate = Date;
      global.Date = class extends Date {
        constructor(...args) {
          if (args.length === 0) {return new originalDate(hour.getTime());}
          return new originalDate(...args);
        }
      };

      const result = await emailService.shouldSendEmail('user-1');

      global.Date = originalDate;

      expect(result).toBe(false);
    });

    it('sends during non-quiet hours', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = {
        userId: 'user-1',
        emailNotifications: true,
        quietHoursEnabled: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
      };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const hour = new Date();
      hour.setHours(12, 0, 0, 0);
      const originalDate = Date;
      global.Date = class extends Date {
        constructor(...args) {
          if (args.length === 0) {return new originalDate(hour.getTime());}
          return new originalDate(...args);
        }
      };

      const result = await emailService.shouldSendEmail('user-1');

      global.Date = originalDate;

      expect(result).toBe(true);
    });
  });

  describe('sendEmailToUser', () => {
    it('sends email when allowed', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: true, quietHoursEnabled: false };
      const user = { id: 'user-1', email: 'admin@test.com' };

      setupDbQueries([
        { via: 'limit', returns: [prefs] },
        { via: 'limit', returns: [user] },
      ]);

      notificationService.sendEmail.mockResolvedValue({ success: true, messageId: 'msg-1' });

      const result = await emailService.sendEmailToUser('user-1', 'Subject', '<p>Body</p>');

      expect(result.success).toBe(true);
      expect(notificationService.sendEmail).toHaveBeenCalledWith('admin@test.com', 'Subject', '<p>Body</p>');
    });

    it('returns PREFERENCES_BLOCKED when not allowed', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: false, quietHoursEnabled: false };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      const result = await emailService.sendEmailToUser('user-1', 'Subject', '<p>Body</p>');

      expect(result).toEqual({ success: false, reason: 'PREFERENCES_BLOCKED' });
      expect(notificationService.sendEmail).not.toHaveBeenCalled();
    });

    it('returns NO_EMAIL when user has no email', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: true, quietHoursEnabled: false };
      const user = { id: 'user-1', email: null };

      setupDbQueries([
        { via: 'limit', returns: [prefs] },
        { via: 'limit', returns: [user] },
      ]);

      const result = await emailService.sendEmailToUser('user-1', 'Subject', '<p>Body</p>');

      expect(result).toEqual({ success: false, reason: 'NO_EMAIL' });
    });

    it('returns NO_EMAIL when user not found', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const prefs = { userId: 'user-1', emailNotifications: true, quietHoursEnabled: false };

      setupDbQueries([
        { via: 'limit', returns: [prefs] },
        { via: 'limit', returns: [] },
      ]);

      const result = await emailService.sendEmailToUser('user-1', 'Subject', '<p>Body</p>');

      expect(result).toEqual({ success: false, reason: 'NO_EMAIL' });
    });
  });

  describe('sendWeeklyDigestToAll', () => {
    it('sends digest to admins respecting preferences', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const admins = [
        { id: 'admin-1', email: 'admin1@test.com', role: 'admin' },
        { id: 'admin-2', email: 'admin2@test.com', role: 'admin' },
      ];
      const prefs1 = { userId: 'admin-1', emailNotifications: true, quietHoursEnabled: false };
      const prefs2 = { userId: 'admin-2', emailNotifications: false, quietHoursEnabled: false };

      setupDbQueries([
        { via: 'where', returns: admins },
        { via: 'limit', returns: [prefs1] },
        { via: 'limit', returns: [prefs2] },
      ]);

      analyticsService.getWeeklySummary.mockResolvedValue({
        periodStart: '2026-04-06',
        generatedAt: new Date().toISOString(),
        newLeads: 10,
        visitsCompleted: 5,
        conversions: 2,
        hotLeadsCount: 3,
        noShows: 1,
      });

      notificationService.sendEmail.mockResolvedValue({ success: true, messageId: 'msg-1' });

      const results = await emailService.sendWeeklyDigestToAll();

      expect(results).toHaveLength(2);
      expect(results[0].success).toBe(true);
      expect(results[1].success).toBe(false);
      expect(results[1].reason).toBe('PREFERENCES_BLOCKED');
    });

    it('returns empty array when no admins', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      setupDbQueries([{ via: 'where', returns: [] }]);

      const results = await emailService.sendWeeklyDigestToAll();

      expect(results).toEqual([]);
    });

    it('skips admins without email', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      const admins = [
        { id: 'admin-1', role: 'admin' },
      ];
      const prefs = { userId: 'admin-1', emailNotifications: true, quietHoursEnabled: false };

      setupDbQueries([
        { via: 'where', returns: admins },
        { via: 'limit', returns: [prefs] },
      ]);

      analyticsService.getWeeklySummary.mockResolvedValue({
        periodStart: '2026-04-06',
        generatedAt: new Date().toISOString(),
        newLeads: 0,
        visitsCompleted: 0,
        conversions: 0,
        hotLeadsCount: 0,
        noShows: 0,
      });

      const results = await emailService.sendWeeklyDigestToAll();

      expect(results).toHaveLength(1);
      expect(results[0].reason).toBe('NO_EMAIL');
    });
  });
});
