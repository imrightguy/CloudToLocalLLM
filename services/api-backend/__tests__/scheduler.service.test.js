jest.mock('node-cron', () => ({
  schedule: jest.fn(),
}));

jest.mock('../src/services/sms.service', () => ({
  getVisitsNeedingMorningReminder: jest.fn(),
  getVisitsNeedingPostSurvey: jest.fn(),
  sendMorningOfReminder: jest.fn(),
  sendPostVisitSurvey: jest.fn(),
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
    it('should schedule morning reminder and post-survey cron jobs', () => {
      startScheduler();

      expect(cron.schedule).toHaveBeenCalledTimes(2);
      expect(cron.schedule).toHaveBeenCalledWith(
        '0 * * * *',
        expect.any(Function),
      );
      expect(cron.schedule).toHaveBeenCalledWith(
        '0 */2 * * *',
        expect.any(Function),
      );
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
    it('should stop both scheduled tasks', () => {
      const mockStop1 = jest.fn();
      const mockStop2 = jest.fn();
      let callCount = 0;
      cron.schedule.mockImplementation(() => {
        callCount++;
        return { stop: callCount === 1 ? mockStop1 : mockStop2 };
      });

      startScheduler();
      stopScheduler();

      expect(mockStop1).toHaveBeenCalledTimes(1);
      expect(mockStop2).toHaveBeenCalledTimes(1);
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

      expect(cron.schedule).toHaveBeenCalledTimes(4); // 2 per start × 2 starts
    });
  });
});
