require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const swaggerUi = require('swagger-ui-express');
const { errorHandler } = require('./utils/apiResponse');
const logger = require('./utils/logger');
const routes = require('./routes');
const swaggerSpec = require('./config/swagger');
const { connect, closeDatabase } = require('./database/connection');
const { initTwilio } = require('./services/twilio.service');
const { startScheduler, stopScheduler } = require('./services/scheduler.service');
const { startWeeklyReport, stopWeeklyReport } = require('./services/weekly-report.service');

const app = express();
const PORT = process.env.PORT || 3000;

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { success: false, error: { message: 'Too many requests', code: 'RATE_LIMIT_EXCEEDED' } },
});

const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400,
};

app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(limiter);

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
    res.status(503).json({ status: 'unhealthy', timestamp: new Date().toISOString(), error: error.message });
  }
});

if (process.env.NODE_ENV !== 'production') {
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
  logger.info('ImmoGestion API started', { port: PORT });
  if (process.env.NODE_ENV !== 'production') {
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
  startWeeklyReport();
});

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
