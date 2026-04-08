const express = require('express');
const { setCORSHeaders } = require('../utils/apiResponse');
const authRoutes = require('./auth.routes');
const buildingRoutes = require('./building.routes');
const employeeRoutes = require('./employee.routes');
const leadRoutes = require('./lead.routes');
const visitRoutes = require('./visit.routes');
const documentRoutes = require('./document.routes');
const scheduleRoutes = require('./schedule.routes');
const communicationRoutes = require('./communication.routes');
const smsRoutes = require('./sms.routes');
const facebookRoutes = require('./facebook.routes');
const analyticsRoutes = require('./analytics.routes');

const router = express.Router();

router.get('/health', (req, res) => {
  setCORSHeaders(res);
  res.json({ status: 'healthy', timestamp: new Date().toISOString(), version: '1.0.0' });
});

router.use('/auth', authRoutes);
router.use('/buildings', buildingRoutes);
router.use('/employees', employeeRoutes);
router.use('/leads', leadRoutes);
router.use('/visits', visitRoutes);
router.use('/documents', documentRoutes);
router.use('/schedules', scheduleRoutes);
router.use('/communications', communicationRoutes);
router.use('/webhooks', smsRoutes);
router.use('/webhooks/facebook', facebookRoutes);
router.use('/analytics', analyticsRoutes);

router.use((err, req, res, next) => {
  setCORSHeaders(res);
  console.error('API Error:', err);
  res.status(500).json({ success: false, error: { message: 'Internal server error', code: 'INTERNAL_ERROR' } });
});

module.exports = router;
