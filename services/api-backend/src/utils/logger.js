/**
 * Structured logger for ImmoGestion API
 * Replaces raw console.log/warn/error with leveled, contextual output.
 */

const LOG_LEVELS = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3,
};

const currentLevel = LOG_LEVELS[process.env.LOG_LEVEL || 'info'] ?? LOG_LEVELS.info;

function formatMessage(level, message, meta = {}) {
  const timestamp = new Date().toISOString();
  const base = { timestamp, level, message };
  const keys = Object.keys(meta);
  if (keys.length > 0) {
    base.context = meta;
  }
  return JSON.stringify(base);
}

function log(level, message, meta) {
  if (LOG_LEVELS[level] > currentLevel) return;
  const formatted = formatMessage(level, message, meta);

  switch (level) {
    case 'error':
      process.stderr.write(formatted + '\n');
      break;
    case 'warn':
      process.stderr.write(formatted + '\n');
      break;
    default:
      process.stdout.write(formatted + '\n');
  }
}

function error(message, meta) {
  log('error', message, meta);
}

function warn(message, meta) {
  log('warn', message, meta);
}

function info(message, meta) {
  log('info', message, meta);
}

function debug(message, meta) {
  log('debug', message, meta);
}

function child(defaultMeta) {
  return {
    error: (msg, meta) => error(msg, { ...defaultMeta, ...meta }),
    warn: (msg, meta) => warn(msg, { ...defaultMeta, ...meta }),
    info: (msg, meta) => info(msg, { ...defaultMeta, ...meta }),
    debug: (msg, meta) => debug(msg, { ...defaultMeta, ...meta }),
  };
}

module.exports = { error, warn, info, debug, child };
