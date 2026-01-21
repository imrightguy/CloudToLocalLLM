/**
 * Centralized Logger for CloudToLocalLLM API Backend
 *
 * Provides structured logging with different levels and formats
 * for development and production environments.
 */

import winston from 'winston';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const NODE_ENV = process.env.NODE_ENV || 'development';
const LOG_DIR = process.env.LOG_DIR || path.join(__dirname, 'logs');

// Custom log format for development
const developmentFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    let log = `${timestamp} [${level}] ${message}`;

    // Add stack trace for errors
    if (stack) {
      log += `\n${stack}`;
    }

    // Add metadata if present
    if (Object.keys(meta).length > 0) {
      log += `\n${JSON.stringify(meta, null, 2)}`;
    }

    return log;
  }),
);

// Custom log format for production
const productionFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json(),
);

// Create transports array
const transports = [
  // Console transport
  new winston.transports.Console({
    format: NODE_ENV === 'development' ? developmentFormat : productionFormat,
    level: LOG_LEVEL,
  }),
];

// Add file transports for production
if (NODE_ENV === 'production') {
  // Ensure log directory exists
  import('fs').then((fs) => {
    if (!fs.existsSync(LOG_DIR)) {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    }
  });

  // Error log file
  transports.push(
    new winston.transports.File({
      filename: path.join(LOG_DIR, 'error.log'),
      level: 'error',
      format: productionFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
    }),
  );

  // Combined log file
  transports.push(
    new winston.transports.File({
      filename: path.join(LOG_DIR, 'combined.log'),
      format: productionFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
    }),
  );
}

// Create logger instance
const logger = winston.createLogger({
  level: LOG_LEVEL,
  format: productionFormat,
  defaultMeta: {
    service: 'cloudtolocalllm-api',
    version: process.env.npm_package_version || '1.0.0',
    environment: NODE_ENV,
  },
  transports,
  // Handle uncaught exceptions and rejections
  exceptionHandlers: [
    new winston.transports.Console({
      format: developmentFormat,
    }),
  ],
  rejectionHandlers: [
    new winston.transports.Console({
      format: developmentFormat,
    }),
  ],
});

// Add request logging helper
logger.logRequest = (req, res, next) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip || req.connection.remoteAddress,
      userId: req.userId || 'anonymous',
    };

    if (res.statusCode >= 400) {
      logger.warn('HTTP Request', logData);
    } else {
      logger.info('HTTP Request', logData);
    }
  });

  if (next) {
    next();
  }
};

// Add structured logging methods for specific components
logger.zrok = {
  info: (message, meta = {}) => logger.info(` [Zrok] ${message}`, meta),
  warn: (message, meta = {}) => logger.warn(` [Zrok] ${message}`, meta),
  error: (message, meta = {}) => logger.error(` [Zrok] ${message}`, meta),
  debug: (message, meta = {}) => logger.debug(` [Zrok] ${message}`, meta),
};

logger.auth = {
  info: (message, meta = {}) => logger.info(` [Auth] ${message}`, meta),
  warn: (message, meta = {}) => logger.warn(` [Auth] ${message}`, meta),
  error: (message, meta = {}) => logger.error(` [Auth] ${message}`, meta),
  debug: (message, meta = {}) => logger.debug(` [Auth] ${message}`, meta),
};

logger.proxy = {
  info: (message, meta = {}) => logger.info(` [Proxy] ${message}`, meta),
  warn: (message, meta = {}) => logger.warn(` [Proxy] ${message}`, meta),
  error: (message, meta = {}) => logger.error(` [Proxy] ${message}`, meta),
  debug: (message, meta = {}) => logger.debug(` [Proxy] ${message}`, meta),
};

logger.container = {
  info: (message, meta = {}) => logger.info(`� [Container] ${message}`, meta),
  warn: (message, meta = {}) => logger.warn(`� [Container] ${message}`, meta),
  error: (message, meta = {}) => logger.error(`� [Container] ${message}`, meta),
  debug: (message, meta = {}) => logger.debug(`� [Container] ${message}`, meta),
};

// Log startup information
logger.info('Logger initialized', {
  level: LOG_LEVEL,
  environment: NODE_ENV,
  logDirectory: NODE_ENV === 'production' ? LOG_DIR : 'console-only',
});

export default logger;
