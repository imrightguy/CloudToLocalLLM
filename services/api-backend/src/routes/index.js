const express = require('express');
const { setCORSHeaders } = require('../utils/apiResponse');
const buildingRoutes = require('./building.routes');
const leadRoutes = require('./lead.routes');
const visitRoutes = require('./visit.routes');
const documentRoutes = require('./document.routes');
const scheduleRoutes = require('./schedule.routes');
const communicationRoutes = require('./communication.routes');
const authRoutes = require('./auth.routes');

const router = express.Router();

// Health check endpoint
router.get('/health', (req, res) => {
  setCORSHeaders(res);
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// API documentation endpoint
router.get('/', (req, res) => {
  setCORSHeaders(res);
  res.json({
    name: 'ImmoGestion API',
    version: '1.0.0',
    description: 'Quebec leasing automation engine API',
    endpoints: {
      'GET /health': 'Health check',
      'GET /': 'API documentation',
      'GET /api/buildings': 'List buildings',
      'POST /api/buildings': 'Create building',
      'GET /api/buildings/:id': 'Get building by ID',
      'PUT /api/buildings/:id': 'Update building',
      'DELETE /api/buildings/:id': 'Delete building',
      'GET /api/units': 'List units',
      'POST /api/units': 'Create unit',
      'GET /api/units/:id': 'Get unit by ID',
      'PUT /api/units/:id': 'Update unit',
      'DELETE /api/units/:id': 'Delete unit',
      'GET /api/leads': 'List leads',
      'POST /api/leads': 'Create lead',
      'GET /api/leads/:id': 'Get lead by ID',
      'PUT /api/leads/:id': 'Update lead',
      'DELETE /api/leads/:id': 'Delete lead',
      'GET /api/visits': 'List visits',
      'POST /api/visits': 'Schedule visit',
      'GET /api/visits/:id': 'Get visit by ID',
      'PUT /api/visits/:id': 'Update visit',
      'DELETE /api/visits/:id': 'Delete visit',
      'GET /api/documents': 'List documents',
      'POST /api/documents': 'Upload document',
      'GET /api/documents/:id': 'Get document by ID',
      'PUT /api/documents/:id': 'Update document',
      'DELETE /api/documents/:id': 'Delete document',
      'GET /api/schedules': 'List schedules',
      'POST /api/schedules': 'Create schedule',
      'GET /api/schedules/:id': 'Get schedule by ID',
      'PUT /api/schedules/:id': 'Update schedule',
      'DELETE /api/schedules/:id': 'Delete schedule',
      'GET /api/communications': 'List communications',
      'POST /api/communications/email': 'Send email',
      'POST /api/communications/sms': 'Send SMS',
      'GET /api/communications/:id': 'Get communication by ID',
      'POST /api/auth/register': 'Register user',
      'POST /api/auth/login': 'Login user',
      'POST /api/auth/logout': 'Logout user',
      'GET /api/auth/profile': 'Get user profile',
      'PUT /api/auth/profile': 'Update user profile',
      'PUT /api/auth/password': 'Change password',
      'GET /api/auth/users': 'List users (admin)',
      'GET /api/auth/users/:id': 'Get user by ID (admin)',
      'PUT /api/auth/users/:id': 'Update user (admin)',
      'DELETE /api/auth/users/:id': 'Delete user (admin)',
    }
  });
});

// Mount API routes
router.use('/auth', authRoutes);
router.use('/buildings', buildingRoutes);
router.use('/leads', leadRoutes);
router.use('/visits', visitRoutes);
router.use('/documents', documentRoutes);
router.use('/schedules', scheduleRoutes);
router.use('/communications', communicationRoutes);

// Error handling middleware
router.use((err, req, res, next) => {
  setCORSHeaders(res);
  console.error('API Error:', err);
  res.status(500).json({
    success: false,
    error: {
      message: 'Internal server error',
      code: 'INTERNAL_ERROR'
    }
  });
});

module.exports = router;