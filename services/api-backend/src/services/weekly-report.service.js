// ─── Weekly Report Cron Service — Phase 4 ───
const cron = require('node-cron');
const notificationService = require('./notification.service');

let scheduledTask = null;

/**
 * Start the weekly report cron job.
 * Runs every Sunday at 5:00 PM (17:00) Eastern time.
 * Cron: 0 17 * * 0
 */
function startWeeklyReport() {
  try {
    if (scheduledTask) {
      console.warn('[weekly-report.service] Cron already running, skipping start');
      return;
    }

    // Initialize mailer on startup
    notificationService.initMailer();

    // Schedule: every Sunday at 5pm
    scheduledTask = cron.schedule('0 17 * * 0', async () => {
      console.log('[weekly-report.service] Running weekly report cron...');
      try {
        const results = await notificationService.sendWeeklySummary();
        console.log(`[weekly-report.service] Weekly report sent: ${JSON.stringify(results)}`);
      } catch (error) {
        console.error('[weekly-report.service] Cron execution error:', error);
      }
    }, {
      scheduled: true,
      timezone: 'America/Montreal',
    });

    console.log('[weekly-report.service] ✅ Weekly report cron started — Sundays at 5:00 PM EST');
  } catch (error) {
    console.error('[weekly-report.service] startWeeklyReport error:', error);
    throw error;
  }
}

/**
 * Stop the weekly report cron job.
 */
function stopWeeklyReport() {
  try {
    if (scheduledTask) {
      scheduledTask.stop();
      scheduledTask = null;
      console.log('[weekly-report.service] Weekly report cron stopped');
    }
  } catch (error) {
    console.error('[weekly-report.service] stopWeeklyReport error:', error);
    throw error;
  }
}

module.exports = {
  startWeeklyReport,
  stopWeeklyReport,
};
