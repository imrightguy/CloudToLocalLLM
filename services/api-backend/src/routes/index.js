const express = require('express');
const { setCORSHeaders } = require('../utils/apiResponse');
const { connect } = require('../database/connection');
const logger = require('../utils/logger');
const authRoutes = require('./auth.routes');
const buildingRoutes = require('./building.routes');
const employeeRoutes = require('./employee.routes');
const leadRoutes = require('./lead.routes');
const leaseRoutes = require('./lease.routes');
const visitRoutes = require('./visit.routes');
const scheduleRoutes = require('./schedule.routes');
const communicationRoutes = require('./communication.routes');
const smsRoutes = require('./sms.routes');
const smsCampaignRoutes = require('./sms-campaign.routes');
const analyticsRoutes = require('./analytics.routes');
const tenantConfirmationRoutes = require('./tenant-confirmation.routes');
const notificationRoutes = require('./notification.routes');
const paymentRoutes = require('./payment.routes');
const renewalRoutes = require('./renewal.routes');
const renovationRoutes = require('./renovation.routes');
const maintenanceRoutes = require('./maintenance.routes');
const photoRoutes = require('./photo.routes');
const renovationJobTemplateRoutes = require('./renovation-job-template.routes');
const plexflowRoutes = require('./plexflow.routes');

const router = express.Router();

router.get('/health', async (req, res) => {
  setCORSHeaders(res);
  try {
    const dbStart = Date.now();
    await connect();
    const dbLatencyMs = Date.now() - dbStart;
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      uptime: process.uptime(),
      database: { status: 'connected', latencyMs: dbLatencyMs },
    });
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      uptime: process.uptime(),
      database: { status: 'disconnected' },
    });
  }
});

router.use('/auth', authRoutes);
router.use('/buildings', buildingRoutes);
router.use('/employees', employeeRoutes);
router.use('/leads', leadRoutes);
router.use('/leases', leaseRoutes);
router.use('/visits', visitRoutes);
router.use('/schedules', scheduleRoutes);
router.use('/communications', communicationRoutes);
router.use('/webhooks', smsRoutes);
router.use('/sms', smsCampaignRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/notifications', notificationRoutes);
router.use('/confirm', tenantConfirmationRoutes);
router.use('/payments', paymentRoutes);
router.use('/renewals', renewalRoutes);
router.use('/renovations', renovationRoutes);
router.use('/maintenance', maintenanceRoutes);
router.use('/plexflow', plexflowRoutes);
router.use('/companies/:companyId/photos', photoRoutes);
router.use('/companies/:companyId/renovation-job-templates', renovationJobTemplateRoutes);

module.exports = router;
