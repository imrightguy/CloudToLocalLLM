const cron = require('node-cron');
const logger = require('../utils/logger');
const {
  getVisitsNeedingMorningReminder,
  getVisitsNeedingPostSurvey,
  sendMorningOfReminder,
  sendPostVisitSurvey,
  getVisitsNeeding24hReminder,
  getVisitsNeeding2hReminder,
  queueVisit24hReminder,
  queueVisit2hReminder,
  getLeasesNeedingRenewalReminder,
  queueLeaseRenewalReminder,
  getPaymentsNeedingReminder,
  queuePaymentReminder,
  getActiveCampaignsDue,
  executeCampaign,
  processQueue,
  expireVisits,
} = require('./sms.service');

let morningReminderTask = null;
let postSurveyTask = null;
let visit24hReminderTask = null;
let visit2hReminderTask = null;
let leaseRenewalTask = null;
let paymentReminderTask = null;
let campaignExecutionTask = null;
let queueProcessorTask = null;
let visitExpiryTask = null;

const startScheduler = () => {
  try {
    morningReminderTask = cron.schedule('0 * * * *', async () => {
      try {
        logger.info('⏰ [Scheduler] Running morning-of reminder check...');
        const visits = await getVisitsNeedingMorningReminder();

        if (visits.length === 0) {
          logger.info('⏰ [Scheduler] No visits needing morning reminders');
          return;
        }

        logger.info(`⏰ [Scheduler] Found ${visits.length} visits needing morning reminders`);
        for (const visit of visits) {
          const result = await sendMorningOfReminder(visit.id);
          if (result.success) {
            logger.info(`  ✅ Morning reminder sent for visit ${visit.id}`);
          } else {
            logger.error(`  ❌ Failed to send morning reminder for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Morning reminder task error:', error.message);
      }
    });

    postSurveyTask = cron.schedule('0 */2 * * *', async () => {
      try {
        logger.info('📝 [Scheduler] Running post-visit survey check...');
        const visits = await getVisitsNeedingPostSurvey();

        if (visits.length === 0) {
          logger.info('📝 [Scheduler] No visits needing post-visit surveys');
          return;
        }

        logger.info(`📝 [Scheduler] Found ${visits.length} visits needing post-visit surveys`);
        for (const visit of visits) {
          const result = await sendPostVisitSurvey(visit.id);
          if (result.success) {
            logger.info(`  ✅ Post-visit survey sent for visit ${visit.id}`);
          } else {
            logger.error(`  ❌ Failed to send post-visit survey for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Post-visit survey task error:', error.message);
      }
    });

    visit24hReminderTask = cron.schedule('*/10 * * * *', async () => {
      try {
        logger.info('📍 [Scheduler] Running 24h visit reminder check...');
        const visits = await getVisitsNeeding24hReminder();

        if (visits.length === 0) {return;}

        logger.info(`📍 [Scheduler] Found ${visits.length} visits needing 24h reminders`);
        for (const visit of visits) {
          const result = await queueVisit24hReminder(visit.id);
          if (result.success) {
            logger.info(`  ✅ 24h reminder queued for visit ${visit.id}`);
          } else {
            logger.error(`  ❌ Failed to queue 24h reminder for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] 24h visit reminder task error:', error.message);
      }
    });

    visit2hReminderTask = cron.schedule('*/2 * * * *', async () => {
      try {
        logger.info('⏰ [Scheduler] Running 2h visit reminder check...');
        const visits = await getVisitsNeeding2hReminder();

        if (visits.length === 0) {return;}

        logger.info(`⏰ [Scheduler] Found ${visits.length} visits needing 2h reminders`);
        for (const visit of visits) {
          const result = await queueVisit2hReminder(visit.id);
          if (result.success) {
            logger.info(`  ✅ 2h reminder queued for visit ${visit.id}`);
          } else {
            logger.error(`  ❌ Failed to queue 2h reminder for visit ${visit.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] 2h visit reminder task error:', error.message);
      }
    });

    leaseRenewalTask = cron.schedule('0 8 * * *', async () => {
      try {
        logger.info('📋 [Scheduler] Running lease renewal reminder check...');
        const leases = await getLeasesNeedingRenewalReminder();

        if (leases.length === 0) {return;}

        logger.info(`📋 [Scheduler] Found ${leases.length} leases needing renewal reminders`);
        for (const lease of leases) {
          const result = await queueLeaseRenewalReminder(lease.id);
          if (result.success) {
            logger.info(`  ✅ Lease renewal reminder queued for lease ${lease.id}`);
          } else {
            logger.error(`  ❌ Failed to queue lease renewal reminder for lease ${lease.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Lease renewal reminder task error:', error.message);
      }
    });

    paymentReminderTask = cron.schedule('0 9 * * *', async () => {
      try {
        logger.info('💰 [Scheduler] Running payment reminder check...');

        const payment3d = await getPaymentsNeedingReminder('payment_3d');
        logger.info(`💰 [Scheduler] Found ${payment3d.length} leases needing 3-day payment reminders`);
        for (const { lease } of payment3d) {
          const result = await queuePaymentReminder(lease.id, 'payment_3d');
          if (result.success) {
            logger.info(`  ✅ 3-day payment reminder queued for lease ${lease.id}`);
          } else {
            logger.error(`  ❌ Failed to queue 3-day payment reminder for lease ${lease.id}: ${result.error}`);
          }
        }

        const paymentDue = await getPaymentsNeedingReminder('payment_due');
        logger.info(`💰 [Scheduler] Found ${paymentDue.length} leases with payment due today`);
        for (const { lease } of paymentDue) {
          const result = await queuePaymentReminder(lease.id, 'payment_due');
          if (result.success) {
            logger.info(`  ✅ Payment due reminder queued for lease ${lease.id}`);
          } else {
            logger.error(`  ❌ Failed to queue payment due reminder for lease ${lease.id}: ${result.error}`);
          }
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Payment reminder task error:', error.message);
      }
    });

    visitExpiryTask = cron.schedule('*/30 * * * *', async () => {
      try {
        logger.info('⏰ [Scheduler] Running visit confirmation expiry check...');
        const result = await expireVisits();
        if (result.expired > 0) {
          logger.info(`⏰ [Scheduler] Expired ${result.expired} unconfirmed visits`);
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Visit expiry task error:', error.message);
      }
    });

    campaignExecutionTask = cron.schedule('*/5 * * * *', async () => {
      try {
        const campaigns = await getActiveCampaignsDue();
        if (campaigns.length === 0) {return;}

        logger.info(`📣 [Scheduler] Found ${campaigns.length} campaigns due for execution`);
        for (const campaign of campaigns) {
          const result = await executeCampaign(campaign.id);
          logger.info(`  📣 Campaign "${campaign.name}": ${result.processed} messages queued`);
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Campaign execution task error:', error.message);
      }
    });

    queueProcessorTask = cron.schedule('* * * * *', async () => {
      try {
        const result = await processQueue();
        if (result.processed > 0) {
          logger.info(`📨 [Scheduler] Queue processed: ${result.sent} sent, ${result.failed} failed`);
        }
      } catch (error) {
        logger.error('❌ [Scheduler] Queue processor task error:', error.message);
      }
    });

    logger.info('✅ SMS scheduler started (queue: 1min, 24h visit: 10min, 2h visit: 2min, lease renewal: 8am, payment: 9am, campaigns: 5min, morning: hourly, survey: 2h, expiry: 30min)');
  } catch (error) {
    logger.error('❌ Failed to start scheduler:', error.message);
  }
};

const stopScheduler = () => {
  try {
    const tasks = [
      { task: morningReminderTask, name: 'morningReminderTask' },
      { task: postSurveyTask, name: 'postSurveyTask' },
      { task: visit24hReminderTask, name: 'visit24hReminderTask' },
      { task: visit2hReminderTask, name: 'visit2hReminderTask' },
      { task: leaseRenewalTask, name: 'leaseRenewalTask' },
      { task: paymentReminderTask, name: 'paymentReminderTask' },
      { task: campaignExecutionTask, name: 'campaignExecutionTask' },
      { task: queueProcessorTask, name: 'queueProcessorTask' },
      { task: visitExpiryTask, name: 'visitExpiryTask' },
    ];

    for (const { task } of tasks) {
      if (task) {
        task.stop();
      }
    }

    morningReminderTask = null;
    postSurveyTask = null;
    visit24hReminderTask = null;
    visit2hReminderTask = null;
    leaseRenewalTask = null;
    paymentReminderTask = null;
    campaignExecutionTask = null;
    queueProcessorTask = null;
    visitExpiryTask = null;

    logger.info('🛑 SMS scheduler stopped');
  } catch (error) {
    logger.error('❌ Error stopping scheduler:', error.message);
  }
};

module.exports = { startScheduler, stopScheduler };
