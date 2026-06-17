const rateLimit = require('express-rate-limit');

const AUTH_WINDOW_MS = parseInt(process.env.AUTH_RATE_LIMIT_WINDOW_MS || '', 10) || 15 * 60 * 1000;
const AUTH_MAX_ATTEMPTS = parseInt(process.env.AUTH_RATE_LIMIT_MAX || '', 10) || 10;

function normalizedEmailFromRequest(req) {
  if (!req || typeof req.body !== 'object' || req.body === null) {
    return '';
  }

  const rawEmail = req.body.email;
  return typeof rawEmail === 'string' ? rawEmail.trim().toLowerCase() : '';
}

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.connection?.remoteAddress || 'unknown';
}

const authLimiter = rateLimit({
  windowMs: AUTH_WINDOW_MS,
  max: AUTH_MAX_ATTEMPTS,
  keyGenerator: (req) => {
    const email = normalizedEmailFromRequest(req);
    const ip = clientIp(req);
    return email ? `${ip}:${email}` : ip;
  },
  message: {
    success: false,
    error: { message: 'Too many login attempts. Please try again later.', code: 'AUTH_RATE_LIMIT_EXCEEDED' },
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
});

const registrationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  message: {
    success: false,
    error: { message: 'Too many registration attempts. Please try again later.', code: 'REGISTRATION_RATE_LIMIT_EXCEEDED' },
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const passwordChangeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  message: {
    success: false,
    error: { message: 'Too many password change attempts. Please try again later.', code: 'PASSWORD_CHANGE_RATE_LIMIT_EXCEEDED' },
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 3,
  message: {
    success: false,
    error: { message: 'Too many password reset attempts. Please try again later.', code: 'PASSWORD_RESET_RATE_LIMIT_EXCEEDED' },
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: {
    success: false,
    error: { message: 'Too many requests from this IP, please try again later.', code: 'RATE_LIMIT_EXCEEDED' },
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
});

module.exports = {
  authLimiter,
  registrationLimiter,
  passwordChangeLimiter,
  passwordResetLimiter,
  apiLimiter,
};
