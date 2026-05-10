const originalEnv = process.env;

beforeEach(() => {
  jest.resetModules();
  process.env = { ...originalEnv };
});

afterAll(() => {
  process.env = originalEnv;
});

describe('config/demo-mode', () => {
  it('returns false when DEMO_MODE is unset', () => {
    delete process.env.DEMO_MODE;
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(false);
  });

  it('returns false when DEMO_MODE is empty', () => {
    process.env.DEMO_MODE = '';
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(false);
  });

  it('returns true when DEMO_MODE=true', () => {
    process.env.DEMO_MODE = 'true';
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(true);
  });

  it('returns true when DEMO_MODE=1', () => {
    process.env.DEMO_MODE = '1';
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(true);
  });

  it('returns true when DEMO_MODE=yes', () => {
    process.env.DEMO_MODE = 'yes';
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(true);
  });

  it('returns true for case-insensitive values', () => {
    process.env.DEMO_MODE = 'TRUE';
    const { isDemoMode } = require('../src/config/demo-mode');
    expect(isDemoMode()).toBe(true);
  });

  it('getDemoModeConfig returns defaults', () => {
    delete process.env.DEMO_USER_EMAIL;
    delete process.env.DEMO_USER_PASSWORD;
    const { getDemoModeConfig } = require('../src/config/demo-mode');
    const config = getDemoModeConfig();
    expect(config.demoUserEmail).toBe('demo@immogestion.app');
    expect(config.demoUserPassword).toBe('Demo2025!');
    expect(config.demoUserRole).toBe('admin');
  });

  it('getDemoModeConfig respects env overrides', () => {
    process.env.DEMO_USER_EMAIL = 'custom@test.com';
    process.env.DEMO_USER_PASSWORD = 'CustomPass!';
    const { getDemoModeConfig } = require('../src/config/demo-mode');
    const config = getDemoModeConfig();
    expect(config.demoUserEmail).toBe('custom@test.com');
    expect(config.demoUserPassword).toBe('CustomPass!');
  });
});
