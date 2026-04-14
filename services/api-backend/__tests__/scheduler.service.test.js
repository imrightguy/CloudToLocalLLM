jest.mock('node-cron', () => ({
  schedule: jest.fn(),
}));

jest.mock('../src/services/sms.service', () => ({
  getVisitsNeedingMorningReminder: jest.fn(),
  getVisitsNeedingPostSurvey: jest.fn(),
  sendMorningOfReminder: jest.fn(),
  sendPostVisitSurvey: jest.fn(),
  getVisitsNeeding24hReminder: jest.fn(),
  getVisitsNeeding2hReminder: jest.fn(),
  queueVisit24hReminder: jest.fn(),
  queueVisit2hReminder: jest.fn(),
  getLeasesNeedingRenewalReminder: jest.fn(),
  queueLeaseRenewalReminder: jest.fn(),
  getPaymentsNeedingReminder: jest.fn(),
  queuePaymentReminder: jest.fn(),
  getActiveCampaignsDue: jest.fn(),
  executeCampaign: jest.fn(),
  processQueue: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const cron = require('node-cron');
const smsService = require('../src/services/sms.service');
const logger = require('../src/utils/logger');

const { startScheduler, stopScheduler } = require('../src/services/scheduler.service');

beforeEach(() => {
  jest.clearAllMocks();
});

describe('scheduler.service', () => {
  describe('startScheduler', () => {
    it('should schedule all cron jobs', () => {
      startScheduler();

      expect(cron.schedule).toHaveBeenCalledTimes(8);
      expect(cron.schedule).toHaveBeenCalledWith('0 * * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('0 */2 * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('*/10 * * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('*/2 * * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('0 8 * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('0 9 * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('*/5 * * * *', expect.any(Function));
      expect(cron.schedule).toHaveBeenCalledWith('* * * * *', expect.any(Function));
    });

    it('should send morning reminders when visits are found', async () => {
      let morningCallback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 * * * *') morningCallback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      const visits = [{ id: 1 }, { id: 2 }];
      smsService.getVisitsNeedingMorningReminder.mockResolvedValue(visits);
      smsService.sendMorningOfReminder.mockResolvedValue({ success: true });

      await morningCallback();

      expect(smsService.getVisitsNeedingMorningReminder).toHaveBeenCalledTimes(1);
      expect(smsService.sendMorningOfReminder).toHaveBeenCalledTimes(2);
    });

    it('should skip morning reminders when no visits found', async () => {
      let morningCallback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 * * * *') morningCallback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getVisitsNeedingMorningReminder.mockResolvedValue([]);

      await morningCallback();

      expect(smsService.sendMorningOfReminder).not.toHaveBeenCalled();
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('No visits needing morning reminders'),
      );
    });

    it('should log error on failed morning reminder send', async () => {
      let morningCallback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 * * * *') morningCallback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getVisitsNeedingMorningReminder.mockResolvedValue([{ id: 99 }]);
      smsService.sendMorningOfReminder.mockResolvedValue({ success: false, error: 'Twilio error' });

      await morningCallback();

      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Failed to send morning reminder'),
      );
    });

    it('should send post-visit surveys when visits are found', async () => {
      let surveyCallback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 */2 * * *') surveyCallback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      const visits = [{ id: 10 }];
      smsService.getVisitsNeedingPostSurvey.mockResolvedValue(visits);
      smsService.sendPostVisitSurvey.mockResolvedValue({ success: true });

      await surveyCallback();

      expect(smsService.sendPostVisitSurvey).toHaveBeenCalledTimes(1);
    });

    it('should queue 24h visit reminders when visits found', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '*/10 * * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getVisitsNeeding24hReminder.mockResolvedValue([{ id: 'v1' }, { id: 'v2' }]);
      smsService.queueVisit24hReminder.mockResolvedValue({ success: true });

      await callback();

      expect(smsService.queueVisit24hReminder).toHaveBeenCalledTimes(2);
    });

    it('should queue 2h visit reminders when visits found', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '*/2 * * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getVisitsNeeding2hReminder.mockResolvedValue([{ id: 'v1' }]);
      smsService.queueVisit2hReminder.mockResolvedValue({ success: true });

      await callback();

      expect(smsService.queueVisit2hReminder).toHaveBeenCalledTimes(1);
    });

    it('should queue lease renewal reminders at 8am', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 8 * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getLeasesNeedingRenewalReminder.mockResolvedValue([{ id: 'l1' }]);
      smsService.queueLeaseRenewalReminder.mockResolvedValue({ success: true });

      await callback();

      expect(smsService.queueLeaseRenewalReminder).toHaveBeenCalledTimes(1);
    });

    it('should queue payment reminders at 9am', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 9 * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getPaymentsNeedingReminder
        .mockResolvedValueOnce([{ lease: { id: 'l1' } }])
        .mockResolvedValueOnce([{ lease: { id: 'l2' } }]);
      smsService.queuePaymentReminder.mockResolvedValue({ success: true });

      await callback();

      expect(smsService.queuePaymentReminder).toHaveBeenCalledTimes(2);
      expect(smsService.queuePaymentReminder).toHaveBeenCalledWith('l1', 'payment_3d');
      expect(smsService.queuePaymentReminder).toHaveBeenCalledWith('l2', 'payment_due');
    });

    it('should execute due campaigns every 5 minutes', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '*/5 * * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getActiveCampaignsDue.mockResolvedValue([{ id: 'c1', name: 'Test' }]);
      smsService.executeCampaign.mockResolvedValue({ success: true, processed: 5 });

      await callback();

      expect(smsService.executeCampaign).toHaveBeenCalledWith('c1');
    });

    it('should process queue every minute', async () => {
      let callback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '* * * * *') callback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.processQueue.mockResolvedValue({ processed: 3, sent: 2, failed: 1 });

      await callback();

      expect(smsService.processQueue).toHaveBeenCalledTimes(1);
    });

    it('should handle errors in morning reminder task gracefully', async () => {
      let morningCallback;
      cron.schedule.mockImplementation((expr, cb) => {
        if (expr === '0 * * * *') morningCallback = cb;
        return { stop: jest.fn() };
      });

      startScheduler();

      smsService.getVisitsNeedingMorningReminder.mockRejectedValue(new Error('DB down'));

      await morningCallback();

      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Morning reminder task error'),
        expect.any(String),
      );
    });
  });

  describe('stopScheduler', () => {
    it('should stop all scheduled tasks', () => {
      const stops = [];
      cron.schedule.mockImplementation(() => {
        const mockStop = jest.fn();
        stops.push(mockStop);
        return { stop: mockStop };
      });

      startScheduler();
      stopScheduler();

      expect(stops).toHaveLength(8);
      for (const s of stops) {
        expect(s).toHaveBeenCalledTimes(1);
      }
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('scheduler stopped'),
      );
    });

    it('should be safe to call when scheduler not started', () => {
      expect(() => stopScheduler()).not.toThrow();
    });

    it('should allow restarting after stop', () => {
      cron.schedule.mockReturnValue({ stop: jest.fn() });

      startScheduler();
      stopScheduler();
      startScheduler();

      expect(cron.schedule).toHaveBeenCalledTimes(16);
    });
  });
});
