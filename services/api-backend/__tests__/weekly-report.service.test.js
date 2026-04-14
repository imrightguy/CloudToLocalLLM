jest.mock('node-cron', () => ({
  schedule: jest.fn(),
}));

jest.mock('../src/services/notification.service', () => ({
  initMailer: jest.fn(),
  sendWeeklySummary: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const cron = require('node-cron');
const notificationService = require('../src/services/notification.service');
const logger = require('../src/utils/logger');

// Require after mocks are set up
const { startWeeklyReport, stopWeeklyReport } = require('../src/services/weekly-report.service');

beforeEach(() => {
  jest.clearAllMocks();
  // Return a mock task object from cron.schedule
  cron.schedule.mockReturnValue({ stop: jest.fn() });
});

afterEach(() => {
  stopWeeklyReport();
});

describe('weekly-report.service', () => {
  describe('startWeeklyReport', () => {
    it('should schedule a cron job with correct expression', () => {
      startWeeklyReport();

      expect(cron.schedule).toHaveBeenCalledWith(
        '0 17 * * 0',
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

    it('should call sendWeeklySummary when cron fires', async () => {
      let cronCallback;
      cron.schedule.mockImplementation((_expr, cb) => {
        cronCallback = cb;
        return { stop: jest.fn() };
      });

      startWeeklyReport();

      notificationService.sendWeeklySummary.mockResolvedValue({ sent: 5 });

      await cronCallback();

      expect(notificationService.sendWeeklySummary).toHaveBeenCalledTimes(1);
      expect(logger.info).toHaveBeenCalledWith(
        expect.stringContaining('Weekly report sent'),
      );
    });

    it('should log error if sendWeeklySummary fails', async () => {
      let cronCallback;
      cron.schedule.mockImplementation((_expr, cb) => {
        cronCallback = cb;
        return { stop: jest.fn() };
      });

      startWeeklyReport();

      notificationService.sendWeeklySummary.mockRejectedValue(new Error('SMTP down'));

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
