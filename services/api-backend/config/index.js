import * as Sentry from '@sentry/node';
import winston from 'winston';
import Transport from 'winston-transport';

// Initialize Sentry Winston Transport
const SentryWinstonTransport = Sentry.createSentryWinstonTransport(Transport);

// Initialize logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'cloudtolocalllm-api' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
    new SentryWinstonTransport({
      level: 'info', // Capture info and above
    }),
  ],
});

// Configuration
const PORT = process.env.PORT || 8080;

export { logger, PORT };
