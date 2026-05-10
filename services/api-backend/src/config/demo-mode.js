const DEMO_MODE_VALUES = new Set(['true', '1', 'yes']);

function isDemoMode() {
  return DEMO_MODE_VALUES.has(
    String(process.env.DEMO_MODE || '').trim().toLowerCase(),
  );
}

function getDemoModeConfig() {
  return {
    enabled: isDemoMode(),
    demoUserEmail: process.env.DEMO_USER_EMAIL || 'demo@immogestion.app',
    demoUserPassword: process.env.DEMO_USER_PASSWORD || 'Demo2025!',
    demoUserRole: 'admin',
  };
}

module.exports = { isDemoMode, getDemoModeConfig };
