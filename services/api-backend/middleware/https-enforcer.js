/**
 * HTTPS Enforcement Middleware
 *
 * Provides HTTPS enforcement and security headers:
 * - Redirects HTTP to HTTPS in production
 * - Sets secure cookie flags
 * - Enables HSTS (HTTP Strict Transport Security) headers
 * - Configures additional security headers
 *
 * Requirement 15: Security and Data Protection
 */

/**
 * Middleware to enforce HTTPS in production
 * Redirects HTTP requests to HTTPS
 */
export function enforceHttps(req, res, next) {
  // Skip HTTPS enforcement in development
  if (process.env.NODE_ENV === 'development') {
    return next();
  }

  // Skip for health check endpoints
  if (req.path === '/health' || req.path === '/api/health') {
    return next();
  }

  // Check if request is secure
  const isSecure =
    req.secure ||
    req.headers['x-forwarded-proto'] === 'https' ||
    req.headers['x-forwarded-ssl'] === 'on';

  if (!isSecure) {
    // Construct HTTPS URL
    const httpsUrl = `https://${req.hostname}${req.url}`;

    console.warn(`HTTP request redirected to HTTPS: ${req.method} ${req.url}`);

    // Redirect to HTTPS with 301 (permanent redirect)
    return res.redirect(301, httpsUrl);
  }

  next();
}

/**
 * Middleware to set HSTS (HTTP Strict Transport Security) header
 * Tells browsers to only use HTTPS for future requests
 */
export function setHstsHeader(req, res, next) {
  // Only set HSTS in production
  if (process.env.NODE_ENV !== 'development') {
    // max-age: 1 year (31536000 seconds)
    // includeSubDomains: Apply to all subdomains
    // preload: Allow inclusion in browser HSTS preload lists
    res.setHeader(
      'Strict-Transport-Security',
      'max-age=31536000; includeSubDomains; preload'
    );
  }

  next();
}

/**
 * Middleware to set secure cookie options
 * Ensures cookies are only sent over HTTPS
 */
export function setSecureCookieOptions(req, res, next) {
  // Override res.cookie to add secure flags
  const originalCookie = res.cookie.bind(res);

  res.cookie = function (name, value, options = {}) {
    // In production, always set secure flag
    if (process.env.NODE_ENV !== 'development') {
      options.secure = true;
    }

    // Always set httpOnly to prevent XSS
    options.httpOnly = true;

    // Set sameSite to prevent CSRF
    options.sameSite = options.sameSite || 'strict';

    // Call original cookie method with enhanced options
    return originalCookie(name, value, options);
  };

  next();
}

/**
 * Middleware to set additional security headers
 */
export function setSecurityHeaders(req, res, next) {
  // X-Content-Type-Options: Prevent MIME type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // X-Frame-Options: Prevent clickjacking
  res.setHeader('X-Frame-Options', 'DENY');

  // X-XSS-Protection: Enable XSS filter (legacy browsers)
  res.setHeader('X-XSS-Protection', '1; mode=block');

  // Referrer-Policy: Control referrer information
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  // Permissions-Policy: Control browser features
  res.setHeader(
    'Permissions-Policy',
    'geolocation=(), microphone=(), camera=(), payment=()'
  );

  next();
}

/**
 * Middleware to check if request is from a secure connection
 * Returns 403 if not secure in production
 */
export function requireHttps(req, res, next) {
  // Skip in development
  if (process.env.NODE_ENV === 'development') {
    return next();
  }

  // Check if request is secure
  const isSecure =
    req.secure ||
    req.headers['x-forwarded-proto'] === 'https' ||
    req.headers['x-forwarded-ssl'] === 'on';

  if (!isSecure) {
    console.error(`HTTPS required: ${req.method} ${req.url} from ${req.ip}`);
    return res.status(403).json({
      error: 'HTTPS required',
      code: 'HTTPS_REQUIRED',
      message: 'This endpoint requires a secure HTTPS connection',
    });
  }

  next();
}

/**
 * Combined HTTPS enforcement middleware
 * Applies all HTTPS-related security measures
 */
export function httpsEnforcement(req, res, next) {
  enforceHttps(req, res, () => {
    setHstsHeader(req, res, () => {
      setSecureCookieOptions(req, res, () => {
        setSecurityHeaders(req, res, next);
      });
    });
  });
}

/**
 * Middleware specifically for admin endpoints
 * Stricter HTTPS enforcement with additional checks
 */
export function adminHttpsEnforcement(req, res, next) {
  // Always require HTTPS for admin endpoints, even in development
  const isSecure =
    req.secure ||
    req.headers['x-forwarded-proto'] === 'https' ||
    req.headers['x-forwarded-ssl'] === 'on';

  if (!isSecure && process.env.NODE_ENV !== 'development') {
    console.error(
      `Admin endpoint requires HTTPS: ${req.method} ${req.url} from ${req.ip}`
    );
    return res.status(403).json({
      error: 'HTTPS required for admin access',
      code: 'ADMIN_HTTPS_REQUIRED',
      message: 'Admin endpoints require a secure HTTPS connection',
    });
  }

  // Set stricter HSTS for admin endpoints
  if (process.env.NODE_ENV !== 'development') {
    res.setHeader(
      'Strict-Transport-Security',
      'max-age=63072000; includeSubDomains; preload' // 2 years
    );
  }

  // Set additional security headers for admin
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader(
    'Permissions-Policy',
    'geolocation=(), microphone=(), camera=(), payment=()'
  );

  // Set secure cookie options
  setSecureCookieOptions(req, res, next);
}

/**
 * Check if the application is running in a secure context
 * @returns {boolean} - True if secure
 */
export function isSecureContext() {
  return (
    process.env.NODE_ENV === 'production' || process.env.FORCE_HTTPS === 'true'
  );
}

/**
 * Get HTTPS configuration status
 * @returns {object} - Configuration status
 */
export function getHttpsConfig() {
  return {
    enforced: isSecureContext(),
    hstsEnabled: process.env.NODE_ENV !== 'development',
    hstsMaxAge: process.env.NODE_ENV !== 'development' ? 31536000 : 0,
    secureCookies: process.env.NODE_ENV !== 'development',
    environment: process.env.NODE_ENV || 'development',
  };
}

export default {
  enforceHttps,
  setHstsHeader,
  setSecureCookieOptions,
  setSecurityHeaders,
  requireHttps,
  httpsEnforcement,
  adminHttpsEnforcement,
  isSecureContext,
  getHttpsConfig,
};
