const cron = require('node-cron');
const {
  getVisitsNeedingMorningReminder,
  getVisitsNeedingPostSurvey,
  sendMorningOfReminder,
  sendPostVisitSurvey,
} = require('./sms.service');

let morningReminderTask = null;
let postSurveyTask = null;

/**
 * Start all scheduled cron jobs.
 * - Every hour (minute 0): send morning-of reminders for tomorrow's visits
 * - Every 2 hours (minute 0): send post-visit surveys for completed visits
 */
const startScheduler = () => {
  try {
    // Morning-of reminders — runs every hour at minute 0
    // Cron: 0 * * * *
    morningReminderTask = cron.schedule('0 * * * *', async () => {
      try {
        console.log('⏰ [Scheduler] Running morning-of reminder check...');
        const visits = await getVisitsNeedingMorningReminder();

        if (visits.length === 0) {
          console.log('⏰ [Scheduler] No visits needing morning reminders');
          return;
        }

        console.log(`⏰ [Scheduler] Found ${visits.length} visits needing morning reminders`);
        for (const visit of visits) {
          const result = await sendMorningOfReminder(visit.id);
          if (result.success) {
            console.log(`  ✅ Morning reminder sent for visit ${visit.id}`);
          } else {
            console.error(`  ❌ Failed to send morning reminder for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        console.error('❌ [Scheduler] Morning reminder task error:', error.message);
      }
    });

    // Post-visit surveys — runs every 2 hours at minute 0
    // Cron: 0 */2 * * *
    postSurveyTask = cron.schedule('0 */2 * * *', async () => {
      try {
        console.log('📝 [Scheduler] Running post-visit survey check...');
        const visits = await getVisitsNeedingPostSurvey();

        if (visits.length === 0) {
          console.log('📝 [Scheduler] No visits needing post-visit surveys');
          return;
        }

        console.log(`📝 [Scheduler] Found ${visits.length} visits needing post-visit surveys`);
        for (const visit of visits) {
          const result = await sendPostVisitSurvey(visit.id);
          if (result.success) {
            console.log(`  ✅ Post-visit survey sent for visit ${visit.id}`);
          } else {
            console.error(`  ❌ Failed to send post-visit survey for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        console.error('❌ [Scheduler] Post-visit survey task error:', error.message);
      }
    });

    console.log('✅ SMS scheduler started (morning reminders: hourly, post-visit surveys: every 2h)');
  } catch (error) {
    console.error('❌ Failed to start scheduler:', error.message);
  }
};

/**
 * Stop all scheduled cron jobs. Called on graceful shutdown.
 */
const stopScheduler = () => {
  try {
    if (morningReminderTask) {
      morningReminderTask.stop();
      morningReminderTask = null;
    }
    if (postSurveyTask) {
      postSurveyTask.stop();
      postSurveyTask = null;
    }
    console.log('🛑 SMS scheduler stopped');
  } catch (error) {
    console.error('❌ Error stopping scheduler:', error.message);
  }
};

module.exports = { startScheduler, stopScheduler };
