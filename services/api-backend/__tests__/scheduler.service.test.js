const {
  startScheduler,
  stopScheduler,
} = require('../src/services/scheduler.service');

// Mock node-cron
jest.mock('node-cron', () => ({
  schedule: jest.fn(() => ({ stop: jest.fn() })),
}));

// Mock logger
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
}));

// Mock sms.service with all required functions
jest.mock('../src/services/sms.service', () => ({
  getVisitsNeedingMorningReminder: jest.fn().mockResolvedValue([]),
  getVisitsNeedingPostSurvey: jest.fn().mockResolvedValue([]),
  sendMorningOfReminder: jest.fn(),
  sendPostVisitSurvey: jest.fn(),
  getVisitsNeeding24hReminder: jest.fn().mockResolvedValue([]),
  getVisitsNeeding2hReminder: jest.fn().mockResolvedValue([]),
  queueVisit24hReminder: jest.fn(),
  queueVisit2hReminder: jest.fn(),
  getLeasesNeedingRenewalReminder: jest.fn().mockResolvedValue([]),
  queueLeaseRenewalReminder: jest.fn(),
  getPaymentsNeedingReminder: jest.fn().mockResolvedValue([]),
  queuePaymentReminder: jest.fn(),
  getActiveCampaignsDue: jest.fn().mockResolvedValue([]),
  executeCampaign: jest.fn(),
  processQueue: jest.fn().mockResolvedValue({ processed: 0, sent: 0, failed: 0 }),
}));

const cron = require('node-cron');
const logger = require('../src/utils/logger');
const smsService = require('../src/services/sms.service');

describe('Scheduler Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    stopScheduler();
  });

  describe('startScheduler', () => {
    it('should register 9 cron tasks', () => {
      startScheduler();
      expect(cron.schedule).toHaveBeenCalledTimes(9);
    });

    it('should use correct cron expressions for each task', () => {
      startScheduler();
      const expressions = cron.schedule.mock.calls.map((call) => call[0]);

      // Queue processor: every minute
      expect(expressions).toContain('* * * * *');
      // Morning reminder: every hour
      expect(expressions).toContain('0 * * * *');
      // Post survey: every 2 hours
      expect(expressions).toContain('0 */2 * * *');
      // 24h visit reminder: every 10 min
      expect(expressions).toContain('*/10 * * * *');
      // 2h visit reminder: every 2 min
      expect(expressions).toContain('*/2 * * * *');
      // Lease renewal: daily at 8am
      expect(expressions).toContain('0 8 * * *');
      // Payment reminder: daily at 9am
      expect(expressions).toContain('0 9 * * *');
      // Campaign execution: every 5 min
      expect(expressions).toContain('*/5 * * * *');
      // Visit confirmation expiry: every 30 min
      expect(expressions).toContain('*/30 * * * *');
    });

    it('should log success message after starting', () => {
      startScheduler();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('SMS scheduler started'),
      );
    });

    it('should catch and log errors during startup', () => {
      cron.schedule.mockImplementationOnce(() => {
        throw new Error('Cron init failed');
      });
      startScheduler();
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to start scheduler'),
        expect.any(String),
      );
    });
  });

  describe('stopScheduler', () => {
    it('should stop all running tasks', () => {
      startScheduler();
      const mockTasks = cron.schedule.mock.results.map((r) => r.value);
      stopScheduler();

      for (const task of mockTasks) {
        expect(task.stop).toHaveBeenCalled();
      }
    });

    it('should log stopped message', () => {
      startScheduler();
      stopScheduler();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('SMS scheduler stopped'),
      );
    });

    it('should handle stop when scheduler was not started', () => {
      expect(() => stopScheduler()).not.toThrow();
    });
  });

  describe('cron task callbacks', () => {
    let callbacks;

    beforeEach(() => {
      callbacks = {};
      cron.schedule.mockImplementation((expr, cb) => {
        callbacks[expr] = cb;
        return { stop: jest.fn() };
      });
      startScheduler();
    });

    it('morning reminder task should query and send reminders', async () => {
      smsService.getVisitsNeedingMorningReminder.mockResolvedValueOnce([
        { id: 1 },
        { id: 2 },
      ]);
      smsService.sendMorningOfReminder
        .mockResolvedValueOnce({ success: true })
        .mockResolvedValueOnce({ success: false, error: 'SMS failed' });

      await callbacks['0 * * * *']();

      expect(smsService.getVisitsNeedingMorningReminder).toHaveBeenCalled();
      expect(smsService.sendMorningOfReminder).toHaveBeenCalledTimes(2);
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('2 visits needing morning reminders'),
      );
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to send morning reminder for visit 2'),
      );
    });

    it('morning reminder task should log when no visits found', async () => {
      smsService.getVisitsNeedingMorningReminder.mockResolvedValueOnce([]);
      await callbacks['0 * * * *']();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('No visits needing morning reminders'),
      );
    });

    it('post survey task should query and send surveys', async () => {
      smsService.getVisitsNeedingPostSurvey.mockResolvedValueOnce([
        { id: 10 },
      ]);
      smsService.sendPostVisitSurvey.mockResolvedValueOnce({ success: true });

      await callbacks['0 */2 * * *']();

      expect(smsService.getVisitsNeedingPostSurvey).toHaveBeenCalled();
      expect(smsService.sendPostVisitSurvey).toHaveBeenCalledWith(10);
    });

    it('24h reminder task should queue reminders', async () => {
      smsService.getVisitsNeeding24hReminder.mockResolvedValueOnce([
        { id: 5 },
      ]);
      smsService.queueVisit24hReminder.mockResolvedValueOnce({ success: true });

      await callbacks['*/10 * * * *']();

      expect(smsService.queueVisit24hReminder).toHaveBeenCalledWith(5);
    });

    it('24h reminder task should return early when no visits', async () => {
      smsService.getVisitsNeeding24hReminder.mockResolvedValueOnce([]);
      await callbacks['*/10 * * * *']();
      expect(smsService.queueVisit24hReminder).not.toHaveBeenCalled();
    });

    it('2h reminder task should queue reminders', async () => {
      smsService.getVisitsNeeding2hReminder.mockResolvedValueOnce([{ id: 7 }]);
      smsService.queueVisit2hReminder.mockResolvedValueOnce({ success: true });

      await callbacks['*/2 * * * *']();

      expect(smsService.queueVisit2hReminder).toHaveBeenCalledWith(7);
    });

    it('lease renewal task should queue renewal reminders', async () => {
      smsService.getLeasesNeedingRenewalReminder.mockResolvedValueOnce([
        { id: 100 },
      ]);
      smsService.queueLeaseRenewalReminder.mockResolvedValueOnce({
        success: true,
      });

      await callbacks['0 8 * * *']();

      expect(smsService.queueLeaseRenewalReminder).toHaveBeenCalledWith(100);
    });

    it('payment reminder task should handle both 3-day and due reminders', async () => {
      smsService.getPaymentsNeedingReminder
        .mockResolvedValueOnce([{ lease: { id: 1 } }])
        .mockResolvedValueOnce([{ lease: { id: 2 } }]);
      smsService.queuePaymentReminder.mockResolvedValue({ success: true });

      await callbacks['0 9 * * *']();

      expect(smsService.getPaymentsNeedingReminder).toHaveBeenCalledWith(
        'payment_3d',
      );
      expect(smsService.getPaymentsNeedingReminder).toHaveBeenCalledWith(
        'payment_due',
      );
      expect(smsService.queuePaymentReminder).toHaveBeenCalledWith(
        1,
        'payment_3d',
      );
      expect(smsService.queuePaymentReminder).toHaveBeenCalledWith(
        2,
        'payment_due',
      );
    });

    it('campaign task should execute due campaigns', async () => {
      smsService.getActiveCampaignsDue.mockResolvedValueOnce([
        { id: 50, name: 'Test Campaign' },
      ]);
      smsService.executeCampaign.mockResolvedValueOnce({ processed: 5 });

      await callbacks['*/5 * * * *']();

      expect(smsService.executeCampaign).toHaveBeenCalledWith(50);
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('5 messages queued'),
      );
    });

    it('campaign task should return early when no campaigns', async () => {
      smsService.getActiveCampaignsDue.mockResolvedValueOnce([]);
      await callbacks['*/5 * * * *']();
      expect(smsService.executeCampaign).not.toHaveBeenCalled();
    });

    it('queue processor should process queue and log results', async () => {
      smsService.processQueue.mockResolvedValueOnce({
        processed: 3,
        sent: 2,
        failed: 1,
      });

      await callbacks['* * * * *']();

      expect(smsService.processQueue).toHaveBeenCalled();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('2 sent, 1 failed'),
      );
    });

    it('queue processor should not log when nothing processed', async () => {
      smsService.processQueue.mockResolvedValueOnce({
        processed: 0,
        sent: 0,
        failed: 0,
      });

      await callbacks['* * * * *']();

      expect(smsService.processQueue).toHaveBeenCalled();
    });

    it('task callbacks should catch and log errors', async () => {
      smsService.getVisitsNeedingMorningReminder.mockRejectedValueOnce(
        new Error('DB connection lost'),
      );

      await callbacks['0 * * * *']();

      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Morning reminder task error'),
        'DB connection lost',
      );
    });
  });
});
