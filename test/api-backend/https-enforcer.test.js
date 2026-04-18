import { describe, it, expect, jest, afterEach, beforeEach } from '@jest/globals';

import {
  enforceHttps,
  setHstsHeader,
  setSecureCookieOptions,
  setSecurityHeaders,
  requireHttps,
  httpsEnforcement,
  adminHttpsEnforcement,
  isSecureContext,
  getHttpsConfig,
} from '../../services/api-backend/middleware/https-enforcer.js';

const originalEnv = { ...process.env };

afterEach(() => {
  Object.assign(process.env, originalEnv);
});

function createMockReq(overrides = {}) {
  return {
    secure: false,
    hostname: 'example.com',
    url: '/test',
    path: '/test',
    method: 'GET',
    ip: '127.0.0.1',
    headers: {},
    ...overrides,
  };
}

function createMockRes() {
  const res = {
    headers: {},
    redirectCalled: false,
    redirectArgs: [],
    statusCode: null,
    jsonBody: null,
    setHeader(key, value) {
      res.headers[key] = value;
    },
    redirect(status, url) {
      res.redirectCalled = true;
      res.redirectArgs = [status, url];
    },
    status(code) {
      res.statusCode = code;
      return res;
    },
    json(body) {
      res.jsonBody = body;
    },
    cookie: jest.fn(),
  };
  return res;
}

const next = jest.fn();

beforeEach(() => {
  jest.clearAllMocks();
});

describe('enforceHttps', () => {
  test('calls next in development mode regardless of protocol', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.redirectCalled).toBe(false);
  });

  test('allows secure requests in production', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: true });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.redirectCalled).toBe(false);
  });

  test('redirects HTTP to HTTPS with x-forwarded-proto', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({
      secure: false,
      headers: { 'x-forwarded-proto': 'https' },
    });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.redirectCalled).toBe(false);
  });

  test('redirects HTTP to HTTPS with x-forwarded-ssl on', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({
      secure: false,
      headers: { 'x-forwarded-ssl': 'on' },
    });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.redirectCalled).toBe(false);
  });

  test('redirects non-secure request with 301', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.redirectCalled).toBe(true);
    expect(res.redirectArgs[0]).toBe(301);
    expect(res.redirectArgs[1]).toBe('https://example.com/test');
  });

  test('skips HTTPS enforcement for /health endpoint', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ path: '/health', secure: false });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('skips HTTPS enforcement for /api/health endpoint', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ path: '/api/health', secure: false });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('preserves query string in redirect URL', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: false, url: '/test?foo=bar', hostname: 'app.example.com' });
    const res = createMockRes();
    enforceHttps(req, res, next);
    expect(res.redirectArgs[1]).toBe('https://app.example.com/test?foo=bar');
  });
});

describe('setHstsHeader', () => {
  test('sets HSTS header in production', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq();
    const res = createMockRes();
    setHstsHeader(req, res, next);
    expect(res.headers['Strict-Transport-Security']).toBe(
      'max-age=31536000; includeSubDomains; preload',
    );
    expect(next).toHaveBeenCalled();
  });

  test('does not set HSTS header in development', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq();
    const res = createMockRes();
    setHstsHeader(req, res, next);
    expect(res.headers['Strict-Transport-Security']).toBeUndefined();
    expect(next).toHaveBeenCalled();
  });
});

describe('setSecureCookieOptions', () => {
  test('wraps res.cookie with secure, httpOnly, sameSite flags in production', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq();
    const res = createMockRes();
    const originalCookie = res.cookie;
    setSecureCookieOptions(req, res, next);
    expect(next).toHaveBeenCalled();

    res.cookie('session', 'abc123');
    expect(originalCookie).toHaveBeenCalledWith('session', 'abc123', {
      secure: true,
      httpOnly: true,
      sameSite: 'strict',
    });
  });

  test('does not set secure flag in development', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq();
    const res = createMockRes();
    const originalCookie = res.cookie;
    setSecureCookieOptions(req, res, next);
    expect(next).toHaveBeenCalled();

    res.cookie('session', 'abc123');
    expect(originalCookie).toHaveBeenCalledWith('session', 'abc123', {
      httpOnly: true,
      sameSite: 'strict',
    });
  });

  test('preserves explicit sameSite option', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq();
    const res = createMockRes();
    const originalCookie = res.cookie;
    setSecureCookieOptions(req, res, next);

    res.cookie('session', 'abc123', { sameSite: 'lax' });
    expect(originalCookie).toHaveBeenCalledWith('session', 'abc123', {
      secure: true,
      httpOnly: true,
      sameSite: 'lax',
    });
  });
});

describe('setSecurityHeaders', () => {
  test('sets all expected security headers', () => {
    const req = createMockReq();
    const res = createMockRes();
    setSecurityHeaders(req, res, next);
    expect(res.headers['X-Content-Type-Options']).toBe('nosniff');
    expect(res.headers['X-Frame-Options']).toBe('DENY');
    expect(res.headers['X-XSS-Protection']).toBe('1; mode=block');
    expect(res.headers['Referrer-Policy']).toBe('strict-origin-when-cross-origin');
    expect(res.headers['Permissions-Policy']).toContain('geolocation=()');
    expect(res.headers['Permissions-Policy']).toContain('microphone=()');
    expect(res.headers['Permissions-Policy']).toContain('camera=()');
    expect(res.headers['Permissions-Policy']).toContain('payment=()');
    expect(next).toHaveBeenCalled();
  });
});

describe('requireHttps', () => {
  test('calls next in development', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    requireHttps(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.statusCode).toBeNull();
  });

  test('allows secure requests', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: true });
    const res = createMockRes();
    requireHttps(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('returns 403 for non-secure requests', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    requireHttps(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(403);
    expect(res.jsonBody.error).toBe('HTTPS required');
    expect(res.jsonBody.code).toBe('HTTPS_REQUIRED');
  });

  test('allows requests with x-forwarded-proto https', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({
      secure: false,
      headers: { 'x-forwarded-proto': 'https' },
    });
    const res = createMockRes();
    requireHttps(req, res, next);
    expect(next).toHaveBeenCalled();
  });
});

describe('httpsEnforcement', () => {
  test('applies all middleware in chain for secure production request', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: true });
    const res = createMockRes();
    httpsEnforcement(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.headers['Strict-Transport-Security']).toBeDefined();
    expect(res.headers['X-Content-Type-Options']).toBe('nosniff');
    expect(res.headers['X-Frame-Options']).toBe('DENY');
  });

  test('skips HTTPS redirect in development but sets no HSTS', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    httpsEnforcement(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.redirectCalled).toBe(false);
    expect(res.headers['Strict-Transport-Security']).toBeUndefined();
  });
});

describe('adminHttpsEnforcement', () => {
  test('sets stricter HSTS (2 years) in production', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: true });
    const res = createMockRes();
    adminHttpsEnforcement(req, res, next);
    expect(res.headers['Strict-Transport-Security']).toBe(
      'max-age=63072000; includeSubDomains; preload',
    );
    expect(next).toHaveBeenCalled();
  });

  test('sets no-referrer policy for admin endpoints', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: true });
    const res = createMockRes();
    adminHttpsEnforcement(req, res, next);
    expect(res.headers['Referrer-Policy']).toBe('no-referrer');
  });

  test('returns 403 for non-secure in production', () => {
    process.env.NODE_ENV = 'production';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    adminHttpsEnforcement(req, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(403);
    expect(res.jsonBody.code).toBe('ADMIN_HTTPS_REQUIRED');
  });

  test('allows non-secure in development', () => {
    process.env.NODE_ENV = 'development';
    const req = createMockReq({ secure: false });
    const res = createMockRes();
    adminHttpsEnforcement(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.statusCode).toBeNull();
  });
});

describe('isSecureContext', () => {
  test('returns true in production', () => {
    process.env.NODE_ENV = 'production';
    expect(isSecureContext()).toBe(true);
  });

  test('returns true when FORCE_HTTPS is true', () => {
    process.env.NODE_ENV = 'development';
    process.env.FORCE_HTTPS = 'true';
    expect(isSecureContext()).toBe(true);
  });

  test('returns false in development without FORCE_HTTPS', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.FORCE_HTTPS;
    expect(isSecureContext()).toBe(false);
  });
});

describe('getHttpsConfig', () => {
  test('returns correct production config', () => {
    process.env.NODE_ENV = 'production';
    const config = getHttpsConfig();
    expect(config.enforced).toBe(true);
    expect(config.hstsEnabled).toBe(true);
    expect(config.hstsMaxAge).toBe(31536000);
    expect(config.secureCookies).toBe(true);
    expect(config.environment).toBe('production');
  });

  test('returns correct development config', () => {
    process.env.NODE_ENV = 'development';
    const config = getHttpsConfig();
    expect(config.enforced).toBe(false);
    expect(config.hstsEnabled).toBe(false);
    expect(config.hstsMaxAge).toBe(0);
    expect(config.secureCookies).toBe(false);
    expect(config.environment).toBe('development');
  });
});
