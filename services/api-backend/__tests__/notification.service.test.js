jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([]),
  },
}));

jest.mock('../src/services/analytics.service', () => ({
  getWeeklySummary: jest.fn(),
}));

jest.mock('nodemailer', () => ({
  createTransport: jest.fn(),
}));

const nodemailer = require('nodemailer');
const notificationService = require('../src/services/notification.service');
const { db } = require('../src/database/connection');
const analyticsService = require('../src/services/analytics.service');

/**
 * Setup db mock for a sequence of queries.
 * Each query is defined as { via: 'limit' | 'where', returns: any }
 * 'limit' = query ends with .limit(1) → promise from .limit()
 * 'where' = query ends with .where(...) → promise from .where()
 *
 * IMPORTANT: .where() is always called (it's in the chain). The difference is
 * whether .limit() follows. So 'where' means .where() should resolve (not chain),
 * while 'limit' means .where() should return this (chain) and .limit() resolves.
 */
function setupDbQueries(queries) {
  let queryIdx = 0;

  db.where.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'where') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return db; // returnThis for chaining
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

describe('notification.service', () => {
  let originalEnv;
  let sendMailMock;

  beforeEach(() => {
    originalEnv = { ...process.env };
    jest.clearAllMocks();

    sendMailMock = jest.fn().mockResolvedValue({ messageId: '<test@example.com>' });
    nodemailer.createTransport.mockReturnValue({ sendMail: sendMailMock });

    db.select.mockReturnThis();
    db.from.mockReturnThis();
    db.where.mockReturnThis();
    db.limit.mockResolvedValue([]);
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  // ─── initMailer ───

  describe('initMailer', () => {
    it('creates transporter with SMTP env vars', () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_PORT = '587';
      process.env.SMTP_USER = 'user@test.com';
      process.env.SMTP_PASS = 'secret';

      notificationService.initMailer();

      expect(nodemailer.createTransport).toHaveBeenCalledWith({
        host: 'smtp.test.com',
        port: 587,
        secure: false,
        auth: { user: 'user@test.com', pass: 'secret' },
      });
    });

    it('sets secure=true when port is 465', () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_PORT = '465';
      process.env.SMTP_USER = 'user@test.com';
      process.env.SMTP_PASS = 'secret';

      notificationService.initMailer();

      expect(nodemailer.createTransport).toHaveBeenCalledWith(
        expect.objectContaining({ secure: true }),
      );
    });

    it('defaults port to 587 when not set', () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_USER = 'user@test.com';
      process.env.SMTP_PASS = 'secret';
      delete process.env.SMTP_PORT;

      notificationService.initMailer();

      expect(nodemailer.createTransport).toHaveBeenCalledWith(
        expect.objectContaining({ port: 587 }),
      );
    });

    it('throws if createTransport fails', () => {
      nodemailer.createTransport.mockImplementationOnce(() => {
        throw new Error('Transport error');
      });
      process.env.SMTP_HOST = 'smtp.test.com';

      expect(() => notificationService.initMailer()).toThrow('Transport error');
    });
  });

  // ─── sendEmail ───

  describe('sendEmail', () => {
    it('sends email and returns success', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_USER = 'noreply@test.com';
      notificationService.initMailer();

      const result = await notificationService.sendEmail('to@test.com', 'Subject', '<p>Body</p>');

      expect(result).toEqual({ success: true, messageId: '<test@example.com>' });
      expect(sendMailMock).toHaveBeenCalledWith(
        expect.objectContaining({ to: 'to@test.com', subject: 'Subject' }),
      );
    });

    it('returns SMTP_NOT_CONFIGURED when SMTP_HOST not set', async () => {
      notificationService.initMailer();
      delete process.env.SMTP_HOST;

      const result = await notificationService.sendEmail('to@test.com', 'Subject', '<p>Body</p>');

      expect(result).toEqual({ success: false, reason: 'SMTP_NOT_CONFIGURED' });
      expect(sendMailMock).not.toHaveBeenCalled();
    });

    it('uses SMTP_FROM for sender', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_FROM = 'custom@test.com';
      notificationService.initMailer();

      await notificationService.sendEmail('to@test.com', 'Subject', '<p>Body</p>');

      expect(sendMailMock).toHaveBeenCalledWith(
        expect.objectContaining({ from: 'custom@test.com' }),
      );
    });

    it('falls back to noreply@immogestion.ca', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      notificationService.initMailer();

      await notificationService.sendEmail('to@test.com', 'Subject', '<p>Body</p>');

      expect(sendMailMock).toHaveBeenCalledWith(
        expect.objectContaining({ from: 'noreply@immogestion.ca' }),
      );
    });

    it('returns failure when sendMail throws', async () => {
      process.env.SMTP_HOST = 'smtp.test.com';
      nodemailer.createTransport.mockReturnValue({
        sendMail: jest.fn().mockRejectedValue(new Error('Connection refused')),
      });
      notificationService.initMailer();

      const result = await notificationService.sendEmail('to@test.com', 'Subject', '<p>Body</p>');

      expect(result.success).toBe(false);
      expect(result.error).toBe('Connection refused');
    });
  });

  // ─── sendWeeklySummary ───

  describe('sendWeeklySummary', () => {
    beforeEach(() => {
      process.env.SMTP_HOST = 'smtp.test.com';
      notificationService.initMailer();
      analyticsService.getWeeklySummary.mockResolvedValue({
        periodStart: '2026-04-06',
        generatedAt: new Date().toISOString(),
        newLeads: 12,
        visitsCompleted: 8,
        conversions: 3,
        hotLeadsCount: 5,
        noShows: 2,
      });
    });

    it('returns undefined when no admin users', async () => {
      // Query: db.select().from(usersTable).where(eq(role, 'admin')) — ends at where
      setupDbQueries([{ via: 'where', returns: [] }]);

      const result = await notificationService.sendWeeklySummary();

      expect(result).toBeUndefined();
      expect(analyticsService.getWeeklySummary).not.toHaveBeenCalled();
    });

    it('sends summary to admins with emails', async () => {
      const admins = [
        { id: 1, email: 'admin1@test.com', role: 'admin' },
        { id: 2, email: 'admin2@test.com', role: 'admin' },
        { id: 3, role: 'admin' },
      ];
      setupDbQueries([{ via: 'where', returns: admins }]);

      const results = await notificationService.sendWeeklySummary();

      expect(results).toHaveLength(2);
      expect(results[0]).toEqual(expect.objectContaining({ email: 'admin1@test.com', success: true }));
      expect(results[1]).toEqual(expect.objectContaining({ email: 'admin2@test.com', success: true }));
    });

    it('includes summary stats in email HTML', async () => {
      setupDbQueries([{ via: 'where', returns: [{ id: 1, email: 'admin@test.com' }] }]);

      await notificationService.sendWeeklySummary();

      const { html } = sendMailMock.mock.calls[0][0];
      expect(html).toContain('12');
      expect(html).toContain('8');
    });

    it('throws when analytics service fails', async () => {
      setupDbQueries([{ via: 'where', returns: [{ id: 1, email: 'admin@test.com' }] }]);
      analyticsService.getWeeklySummary.mockRejectedValue(new Error('DB down'));

      await expect(notificationService.sendWeeklySummary()).rejects.toThrow('DB down');
    });
  });

  // ─── sendHotLeadNotification ───

  describe('sendHotLeadNotification', () => {
    beforeEach(() => {
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.APP_URL = 'https://app.immogestion.ca';
      notificationService.initMailer();
    });

    it('returns LEAD_NOT_FOUND when lead missing', async () => {
      // Query 1: lead (.where().limit(1)) → ends at limit
      setupDbQueries([{ via: 'limit', returns: [] }]);

      const result = await notificationService.sendHotLeadNotification(999);

      expect(result).toEqual({ success: false, reason: 'LEAD_NOT_FOUND' });
    });

    it('returns NO_ADMINS when no admin users', async () => {
      const lead = {
        id: 1, fullName: 'Jean', source: 'facebook', language: 'fr', buildingId: null,
      };
      // Query 1: lead → limit. Query 2: admins → where.
      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: [] },
      ]);

      const result = await notificationService.sendHotLeadNotification(1);

      expect(result).toEqual({ success: false, reason: 'NO_ADMINS' });
    });

    it('sends notification with lead details', async () => {
      const lead = {
        id: 1, fullName: 'Jean Dupont', phone: '514-555-1234', source: 'facebook', language: 'fr', buildingId: null,
      };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: admins },
      ]);

      const results = await notificationService.sendHotLeadNotification(1);

      expect(results).toHaveLength(1);
      expect(results[0].success).toBe(true);

      const email = sendMailMock.mock.calls[0][0];
      expect(email.subject).toContain('Lead Chaud');
      expect(email.subject).toContain('Jean Dupont');
      expect(email.html).toContain('Jean Dupont');
      expect(email.html).toContain('514-555-1234');
      expect(email.html).toContain('Facebook');
    });

    it('includes building name when lead has buildingId', async () => {
      const lead = {
        id: 1, fullName: 'Jean', source: 'website', language: 'en', buildingId: 10,
      };
      const building = { id: 10, name: 'Tour des Cedres' };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      // Query order in service: lead → admins → building (building query is inside if block after admins check)
      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: admins },
        { via: 'limit', returns: [building] },
      ]);

      await notificationService.sendHotLeadNotification(1);

      expect(sendMailMock.mock.calls[0][0].html).toContain('Tour des Cedres');
    });

    it('shows Anglais for English leads', async () => {
      const lead = {
        id: 1, fullName: 'John Smith', source: 'website', language: 'en', buildingId: null,
      };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: admins },
      ]);

      await notificationService.sendHotLeadNotification(1);

      expect(sendMailMock.mock.calls[0][0].html).toContain('Anglais');
    });

    it('skips admins without email', async () => {
      const lead = {
        id: 1, fullName: 'Test', source: 'other', language: 'fr', buildingId: null,
      };
      const admins = [
        { id: 1, role: 'admin' },
        { id: 2, email: 'admin@test.com', role: 'admin' },
      ];

      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: admins },
      ]);

      const results = await notificationService.sendHotLeadNotification(1);

      expect(results).toHaveLength(1);
      expect(results[0].email).toBe('admin@test.com');
    });

    it('includes CTA link with APP_URL', async () => {
      const lead = {
        id: 1, fullName: 'Test', source: 'other', language: 'fr', buildingId: null,
      };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      setupDbQueries([
        { via: 'limit', returns: [lead] },
        { via: 'where', returns: admins },
      ]);

      await notificationService.sendHotLeadNotification(1);

      expect(sendMailMock.mock.calls[0][0].html).toContain('https://app.immogestion.ca/leads');
    });
  });

  // ─── sendNoShowAlert ───

  describe('sendNoShowAlert', () => {
    beforeEach(() => {
      process.env.SMTP_HOST = 'smtp.test.com';
      notificationService.initMailer();
    });

    it('returns VISIT_NOT_FOUND when visit missing', async () => {
      setupDbQueries([{ via: 'limit', returns: [] }]);

      const result = await notificationService.sendNoShowAlert(999);

      expect(result).toEqual({ success: false, reason: 'VISIT_NOT_FOUND' });
    });

    it('returns VISIT_NOT_FOUND for soft-deleted visits', async () => {
      setupDbQueries([{ via: 'limit', returns: [{ id: 1, isActive: false }] }]);

      const result = await notificationService.sendNoShowAlert(1);

      expect(result).toEqual({ success: false, reason: 'VISIT_NOT_FOUND' });
      expect(sendMailMock).not.toHaveBeenCalled();
    });

    it('sends alert with N/A for missing lead/employee', async () => {
      const visit = {
        id: 1, leadId: 5, employeeId: 10, unitId: null, dateTime: '2026-04-08T14:00:00',
      };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      // visit → limit, lead → limit, employee → limit, admins → where
      setupDbQueries([
        { via: 'limit', returns: [visit] },
        { via: 'limit', returns: [] },
        { via: 'limit', returns: [] },
        { via: 'where', returns: admins },
      ]);

      const results = await notificationService.sendNoShowAlert(1);

      expect(results).toHaveLength(1);
      expect(results[0].success).toBe(true);
      expect(sendMailMock.mock.calls[0][0].html).toContain('N/A');
    });

    it('includes lead and employee names', async () => {
      const visit = {
        id: 1, leadId: 5, employeeId: 10, unitId: null, dateTime: '2026-04-08T14:00:00',
      };
      const lead = { id: 5, fullName: 'Marie Tremblay', phone: '514-555-9999' };
      const employee = { id: 10, firstName: 'Pierre', lastName: 'Martin' };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      setupDbQueries([
        { via: 'limit', returns: [visit] },
        { via: 'limit', returns: [lead] },
        { via: 'limit', returns: [employee] },
        { via: 'where', returns: admins },
      ]);

      await notificationService.sendNoShowAlert(1);

      const { html } = sendMailMock.mock.calls[0][0];
      expect(html).toContain('Marie Tremblay');
      expect(html).toContain('Pierre Martin');
    });

    it('defaults building to Non assigné when no unit', async () => {
      const visit = {
        id: 1, leadId: 5, employeeId: 10, unitId: null, dateTime: '2026-04-08T14:00:00',
      };
      const lead = { id: 5, fullName: 'Test' };
      const admins = [{ id: 1, email: 'admin@test.com', role: 'admin' }];

      setupDbQueries([
        { via: 'limit', returns: [visit] },
        { via: 'limit', returns: [lead] },
        { via: 'limit', returns: [] },
        { via: 'where', returns: admins },
      ]);

      await notificationService.sendNoShowAlert(1);

      expect(sendMailMock.mock.calls[0][0].html).toContain('Non assigné');
    });

    it('throws on database errors', async () => {
      db.limit.mockImplementationOnce(() => { throw new Error('Connection lost'); });

      await expect(notificationService.sendNoShowAlert(1)).rejects.toThrow('Connection lost');
    });
  });
});
