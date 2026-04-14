const cron = require('node-cron');
const notificationService = require('./notification.service');
const emailService = require('./email.service');
const logger = require('../utils/logger');

let scheduledTask = null;

function startWeeklyReport() {
  try {
    if (scheduledTask) {
      logger.warn('[weekly-report.service] Cron already running, skipping start');
      return;
    }

    notificationService.initMailer();

    scheduledTask = cron.schedule('0 8 * * 1', async () => {
      logger.info('[weekly-report.service] Running weekly report cron...');
      try {
        const results = await emailService.sendWeeklyDigestToAll();
        logger.info(`[weekly-report.service] Weekly digest sent: ${JSON.stringify(results)}`);
      } catch (error) {
        logger.error('[weekly-report.service] Cron execution error:', error);
      }
    }, {
      scheduled: true,
      timezone: 'America/Montreal',
    });

    logger.info('[weekly-report.service] Weekly digest cron started — Mondays at 8:00 AM EST');
  } catch (error) {
    logger.error('[weekly-report.service] startWeeklyReport error:', error);
    throw error;
  }
}

function stopWeeklyReport() {
  try {
    if (scheduledTask) {
      scheduledTask.stop();
      scheduledTask = null;
      logger.info('[weekly-report.service] Weekly report cron stopped');
    }
  } catch (error) {
    logger.error('[weekly-report.service] stopWeeklyReport error:', error);
    throw error;
  }
}

module.exports = {
  startWeeklyReport,
  stopWeeklyReport,
};
