import express from 'express';
import path from 'path';
import { promises as fs } from 'fs';
import logger from '../logger.js';

const router = express.Router();
let logDir = process.env.CLIENT_LOG_DIR || '/tmp/logs';
const logFileName = process.env.CLIENT_LOG_FILE || 'client-web.log';
let logFilePath = path.join(logDir, logFileName);

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

router.post('/', async (req, res) => {
  try {
    const { entries, source = 'web-client', sessionId = null } = req.body || {};

    if (!Array.isArray(entries) || entries.length === 0) {
      return res.status(400).json({ error: 'entries array is required' });
    }

    const sanitized = entries.slice(0, 200).map((entry) => ({
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
