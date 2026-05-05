const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
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
