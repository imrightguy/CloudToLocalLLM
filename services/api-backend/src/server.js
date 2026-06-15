require('dotenv').config();
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const helmet = require('helmet');
const swaggerUi = require('swagger-ui-express');
const { errorHandler } = require('./utils/apiResponse');
const logger = require('./utils/logger');
const routes = require('./routes');
const swaggerSpec = require('./config/swagger');
const { connect, closeDatabase } = require('./database/connection');
const { initTwilio } = require('./services/twilio.service');
const { startScheduler, stopScheduler } = require('./services/scheduler.service');
const { apiLimiter } = require('./middleware/rateLimiters');

const isProduction = process.env.NODE_ENV === 'production';

if (isProduction) {
  const required = [
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
    'DATABASE_URL',
    'VAPI_WEBHOOK_SECRET',
    'MARKETPLACE_WEBHOOK_SECRET',
  ];
  const missing = required.filter(k => !process.env[k]);
  if (missing.length) {
    console.error(`FATAL: Missing required env vars: ${missing.join(', ')}`);
    process.exit(1);
  }
  if (process.env.JWT_SECRET.length < 32) {
    console.error('FATAL: JWT_SECRET must be at least 32 characters in production');
    process.exit(1);
  }
  if (process.env.JWT_REFRESH_SECRET.length < 32) {
    console.error('FATAL: JWT_REFRESH_SECRET must be at least 32 characters in production');
    process.exit(1);
  }
  if (!process.env.ALLOWED_ORIGINS || process.env.ALLOWED_ORIGINS.includes('*')) {
    console.error('FATAL: ALLOWED_ORIGINS must be set to specific domains in production (no wildcard)');
    process.exit(1);
  }
}

const app = express();
app.set('trust proxy', process.env.TRUST_PROXY ?? (isProduction ? 1 : false));
const PORT = process.env.PORT || 3000;

const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400,
};

app.use(helmet({
  contentSecurityPolicy: isProduction ? {
    directives: { defaultSrc: ["'self'"] },
  } : false,
  hsts: isProduction ? { maxAge: 31536000, includeSubDomains: true, preload: true } : false,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
app.use(cors(corsOptions));
app.use(express.json({
  limit: '10mb',
  verify: (req, _res, buf) => { req.rawBody = buf; },
}));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());
app.use(apiLimiter);

app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, { method: req.method, path: req.path });
  next();
});

/**
 * @swagger
 * /health:
 *   get:
 *     tags: [System]
 *     summary: Health check
 *     description: Returns server health status including uptime and database connectivity.
 *     responses:
 *       200:
 *         description: Server is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 uptime:
 *                   type: number
 *       503:
 *         description: Server is unhealthy (DB disconnected)
 */
app.get('/health', async (req, res) => {
  try {
    await connect();
    res.json({ status: 'healthy', timestamp: new Date().toISOString(), uptime: process.uptime() });
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    res.status(503).json({ status: 'unhealthy', timestamp: new Date().toISOString() });
  }
});

if (!isProduction) {
  app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'ImmoGestion API Docs',
  }));
  app.get('/api/docs.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(swaggerSpec);
  });
}

app.use('/api', routes);

app.use('*', (req, res) => {
  res.status(404).json({ success: false, error: { message: 'Route not found', code: 'NOT_FOUND' } });
});

app.use(errorHandler);

app.listen(PORT, async () => {
  logger.info('ImmoGestion API started', { port: PORT, env: process.env.NODE_ENV || 'development' });
  if (!isProduction) {
    logger.info(`Swagger docs available at http://localhost:${PORT}/api/docs`);
  }
  try {
    await connect();
    logger.info('Database connected');
  } catch (error) {
    logger.error('Database connection failed', { message: error.message, stack: error.stack });
    process.exit(1);
  }

  initTwilio();
  startScheduler();
});

const shutdown = async () => {
  logger.info('Shutting down');
  stopScheduler();
  await closeDatabase();
  process.exit(0);
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

module.exports = app;
