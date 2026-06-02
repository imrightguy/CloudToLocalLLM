import express from 'express';
import { z } from 'zod';
import path from 'path';
import { promises as fs } from 'fs';
import logger from '../logger.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();
let logDir = process.env.CLIENT_LOG_DIR || '/tmp/logs';
const logFileName = process.env.CLIENT_LOG_FILE || 'client-web.log';
let logFilePath = path.join(logDir, logFileName);

const logEntrySchema = z.object({
  timestamp: z.string().datetime().optional(),
  level: z.string().optional(),
  message: z.any(),
  url: z.string().url().nullable().optional(),
  userAgent: z.string().nullable().optional(),
});

const clientLogsBodySchema = z.object({
  entries: z.array(logEntrySchema).min(1).max(200),
  source: z.string().optional(),
  sessionId: z.string().nullable().optional(),
});

async function ensureLogDirectory() {
  try {
    await fs.mkdir(logDir, { recursive: true });
    await fs.access(logDir, fs.constants.W_OK);
  } catch (error) {
    if (logDir !== '/tmp/logs') {
      logger.warn(
        `[ClientLogs] Failed to access configured log directory ${logDir}, falling back to /tmp/logs`,
        { error: error.message },
      );
      logDir = '/tmp/logs';
      logFilePath = path.join(logDir, logFileName);
      await fs.mkdir(logDir, { recursive: true });
    } else {
      throw error;
    }
  }
}

router.post('/', validateSchema({ body: clientLogsBodySchema }), async (req, res) => {
  try {
    const { entries, source = 'web-client', sessionId = null } = req.body;

    const sanitized = entries.map((entry) => ({
      timestamp: entry?.timestamp || new Date().toISOString(),
      level: entry?.level || 'INFO',
      message:
        typeof entry?.message === 'string'
          ? entry.message
          : JSON.stringify(entry?.message ?? ''),
      url: entry?.url || null,
      userAgent: entry?.userAgent || req.get('user-agent') || null,
      source,
      sessionId,
    }));

    await ensureLogDirectory();
    const payload =
      sanitized.map((entry) => JSON.stringify(entry)).join('\n') + '\n';
    await fs.appendFile(logFilePath, payload, 'utf8');

    res.json({ success: true, count: sanitized.length });
  } catch (error) {
    logger.error('[ClientLogs] Failed to persist log entries', error);
    res.status(500).json({ error: 'Failed to persist logs' });
  }
});

export default router;
