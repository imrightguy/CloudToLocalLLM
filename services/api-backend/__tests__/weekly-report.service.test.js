jest.mock('node-cron', () => ({
  schedule: jest.fn(),
}));

jest.mock('../src/services/notification.service', () => ({
  initMailer: jest.fn(),
}));

jest.mock('../src/services/email.service', () => ({
  sendWeeklyDigestToAll: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const cron = require('node-cron');
const notificationService = require('../src/services/notification.service');
const emailService = require('../src/services/email.service');
const logger = require('../src/utils/logger');

const { startWeeklyReport, stopWeeklyReport } = require('../src/services/weekly-report.service');

beforeEach(() => {
  jest.clearAllMocks();
  cron.schedule.mockReturnValue({ stop: jest.fn() });
});

afterEach(() => {
  stopWeeklyReport();
});

describe('weekly-report.service', () => {
  describe('startWeeklyReport', () => {
    it('should schedule a cron job for Monday 8am', () => {
      startWeeklyReport();

      expect(cron.schedule).toHaveBeenCalledWith(
        '0 8 * * 1',
        expect.any(Function),
        expect.objectContaining({
          scheduled: true,
          timezone: 'America/Montreal',
        }),
      );
    });

    it('should initialize the mailer on start', () => {
      startWeeklyReport();

      expect(notificationService.initMailer).toHaveBeenCalledTimes(1);
    });

    it('should not start a second cron if already running', () => {
      startWeeklyReport();
      startWeeklyReport();

      expect(cron.schedule).toHaveBeenCalledTimes(1);
      expect(logger.warn).toHaveBeenCalledWith(
        expect.stringContaining('already running'),
      );
    });

    it('should call sendWeeklyDigestToAll when cron fires', async () => {
      let cronCallback;
      cron.schedule.mockImplementation((_expr, cb) => {
        cronCallback = cb;
        return { stop: jest.fn() };
      });

      startWeeklyReport();

      emailService.sendWeeklyDigestToAll.mockResolvedValue([{ sent: 5 }]);

      await cronCallback();

      expect(emailService.sendWeeklyDigestToAll).toHaveBeenCalledTimes(1);
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('Weekly digest sent'),
      );
    });

    it('should log error if sendWeeklyDigestToAll fails', async () => {
      let cronCallback;
      cron.schedule.mockImplementation((_expr, cb) => {
        cronCallback = cb;
        return { stop: jest.fn() };
      });

      startWeeklyReport();

      emailService.sendWeeklyDigestToAll.mockRejectedValue(new Error('SMTP down'));

      await cronCallback();

      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Cron execution error'),
        expect.any(Error),
      );
    });
  });

  describe('stopWeeklyReport', () => {
    it('should stop the scheduled task if running', () => {
      const mockStop = jest.fn();
      cron.schedule.mockReturnValue({ stop: mockStop });

      startWeeklyReport();
      stopWeeklyReport();

      expect(mockStop).toHaveBeenCalledTimes(1);
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('stopped'),
      );
    });

    it('should be safe to call when no task is running', () => {
      expect(() => stopWeeklyReport()).not.toThrow();
    });

    it('should allow restarting after stop', () => {
      const mockStop = jest.fn();
      cron.schedule.mockReturnValue({ stop: mockStop });

      startWeeklyReport();
      stopWeeklyReport();
      startWeeklyReport();

      expect(cron.schedule).toHaveBeenCalledTimes(2);
    });
  });
});
