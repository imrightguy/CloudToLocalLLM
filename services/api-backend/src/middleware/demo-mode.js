const { isDemoMode } = require('../config/demo-mode');

const WRITE_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

const DEMO_WRITE_EXEMPT_PATHS = [
  '/demo/login',
  '/auth/login',
  '/auth/refresh',
  '/admin/seed',
  '/api/demo/login',
  '/api/auth/login',
  '/api/auth/refresh',
  '/api/admin/seed',
];

function isExemptPath(path) {
  return DEMO_WRITE_EXEMPT_PATHS.some((p) => path.startsWith(p));
}

function demoModeContext(req, res, next) {
  req.demoMode = isDemoMode();
  res.setHeader('X-Demo-Mode', req.demoMode ? 'true' : 'false');
  next();
}

function demoWriteGuard(req, res, next) {
  if (!isDemoMode()) {
    return next();
  }

  if (!WRITE_METHODS.has(req.method)) {
    return next();
  }

  if (isExemptPath(req.path)) {
    return next();
  }

  return res.status(403).json({
    success: false,
    error: {
      message: 'Write operations are disabled in demo mode',
      code: 'DEMO_WRITE_BLOCKED',
    },
  });
}

module.exports = { demoModeContext, demoWriteGuard };
