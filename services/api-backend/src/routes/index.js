const express = require('express');
const { setCORSHeaders } = require('../utils/apiResponse');
const { connect } = require('../database/connection');
const authRoutes = require('./auth.routes');
const buildingRoutes = require('./building.routes');
const employeeRoutes = require('./employee.routes');
const leadRoutes = require('./lead.routes');
const leaseRoutes = require('./lease.routes');
const visitRoutes = require('./visit.routes');
const documentRoutes = require('./document.routes');
const scheduleRoutes = require('./schedule.routes');
const communicationRoutes = require('./communication.routes');
const smsRoutes = require('./sms.routes');
const smsCampaignRoutes = require('./sms-campaign.routes');
const facebookRoutes = require('./facebook.routes');
const analyticsRoutes = require('./analytics.routes');
const tenantConfirmationRoutes = require('./tenant-confirmation.routes');
const notificationRoutes = require('./notification.routes');
const adminRoutes = require('./admin.routes');

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
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      uptime: process.uptime(),
      database: { status: 'disconnected', error: error.message },
    });
  }
});

router.use('/auth', authRoutes);
router.use('/buildings', buildingRoutes);
router.use('/employees', employeeRoutes);
router.use('/leads', leadRoutes);
router.use('/leases', leaseRoutes);
router.use('/visits', visitRoutes);
router.use('/documents', documentRoutes);
router.use('/schedules', scheduleRoutes);
router.use('/communications', communicationRoutes);
router.use('/webhooks', smsRoutes);
router.use('/webhooks/facebook', facebookRoutes);
router.use('/sms', smsCampaignRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/notifications', notificationRoutes);
router.use('/confirm', tenantConfirmationRoutes);
router.use('/admin', adminRoutes);

module.exports = router;
