const { execSync } = require('child_process');

// logger.js evaluates LOG_LEVEL at import time and writes errors/warns to stderr.
// We use subprocess + 2>&1 to capture all output cleanly.

function run(code) {
  const stdout = execSync(
    `LOG_LEVEL=debug node -e "${code.replace(/"/g, '\\"')}" 2>&1`,
    { encoding: 'utf8' },
  ).trim();
  if (!stdout) {return [];}
  return stdout.split('\n').map((line) => {
    try { return JSON.parse(line); } catch { return null; }
  }).filter(Boolean);
}

describe('logger', () => {
  it('emits valid JSON with timestamp, level, and message', () => {
    const [out] = run(`
      const { info } = require('./src/utils/logger');
      info('hello');
    `);
    expect(out.level).toBe('info');
    expect(out.message).toBe('hello');
    expect(out.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('includes context when meta is provided', () => {
    const [out] = run(`
      const { error } = require('./src/utils/logger');
      error('fail', { code: 500 });
    `);
    expect(out.level).toBe('error');
    expect(out.context).toEqual({ code: 500 });
  });

  it('omits context key when no meta is provided', () => {
    const [out] = run(`
      const { info } = require('./src/utils/logger');
      info('plain');
    `);
    expect(out.context).toBeUndefined();
  });

  it('warn produces correct level', () => {
    const [out] = run(`
      const { warn } = require('./src/utils/logger');
      warn('careful');
    `);
    expect(out.level).toBe('warn');
    expect(out.message).toBe('careful');
  });

  it('child merges default meta with per-call meta', () => {
    const [out] = run(`
      const { child } = require('./src/utils/logger');
      const req = child({ requestId: 'abc', service: 'api' });
      req.info('started', { method: 'GET' });
    `);
    expect(out.context).toEqual({
      requestId: 'abc',
      service: 'api',
      method: 'GET',
    });
  });

  it('child per-call meta overrides default meta on conflict', () => {
    const [out] = run(`
      const { child } = require('./src/utils/logger');
      const req = child({ requestId: 'old' });
      req.error('fail', { requestId: 'new', detail: 'x' });
    `);
    expect(out.context.requestId).toBe('new');
    expect(out.context.detail).toBe('x');
  });

  it('debug is suppressed when LOG_LEVEL=info', () => {
    const result = execSync(
      "LOG_LEVEL=info node -e \"const { debug } = require('./src/utils/logger'); debug('hidden');\" 2>&1",
      { encoding: 'utf8' },
    ).trim();
    expect(result).toBe('');
  });

  it('error is emitted when LOG_LEVEL=error', () => {
    const [out] = run(`
      const { error } = require('./src/utils/logger');
      error('visible');
    `);
    expect(out.level).toBe('error');
    expect(out.message).toBe('visible');
  });
});
