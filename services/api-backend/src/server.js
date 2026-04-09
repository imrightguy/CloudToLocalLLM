require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { errorHandler } = require('./utils/apiResponse');
const logger = require('./utils/logger');
const routes = require('./routes');
const { connect, closeDatabase } = require('./database/connection');
const { initTwilio } = require('./services/twilio.service');
const { startScheduler, stopScheduler } = require('./services/scheduler.service');
const { startWeeklyReport, stopWeeklyReport } = require('./services/weekly-report.service');

const app = express();
const PORT = process.env.PORT || 3000;

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { success: false, error: { message: 'Too many requests', code: 'RATE_LIMIT_EXCEEDED' } },
});

// CORS
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400,
};

// Middleware
app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(limiter);

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, { method: req.method, path: req.path });
  next();
});

// Health check (with DB ping)
app.get('/health', async (req, res) => {
  try {
    await connect();
    res.json({ status: 'healthy', timestamp: new Date().toISOString(), uptime: process.uptime() });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', timestamp: new Date().toISOString(), error: error.message });
  }
});

// API routes (includes /api/auth via routes/index.js)
app.use('/api', routes);

// 404
app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: { message: 'Route not found', code: 'NOT_FOUND' } });
});

// Error handler
app.use(errorHandler);

// Start
app.listen(PORT, async () => {
  logger.info('ImmoGestion API started', { port: PORT });
  try {
    await connect();
    logger.info('Database connected');
  } catch (error) {
    logger.error('Database connection failed', { message: error.message, stack: error.stack });
    process.exit(1);
  }

  // Initialize Twilio client
  initTwilio();

  // Start SMS scheduler (cron jobs)
  startScheduler();

  // Start weekly email report (Sunday 5pm)
  startWeeklyReport();
});

// Graceful shutdown
const shutdown = async () => {
  logger.info('Shutting down');
  stopScheduler();
  stopWeeklyReport();
  await closeDatabase();
  process.exit(0);
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

module.exports = app;
