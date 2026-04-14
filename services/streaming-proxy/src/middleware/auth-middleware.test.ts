/**
 * Authentication Middleware Tests
 * Comprehensive tests for JWT validation, user context, and audit logging
 */

import { JWTValidationMiddleware } from './jwt-validation-middleware';
import { UserContextManager } from './user-context-manager';
import { AuthAuditLogger } from './auth-audit-logger';
import { UserTier } from '../interfaces/auth-middleware';
import { JWTValidator } from './jwt-validator.interface';
import { jest } from '@jest/globals';

// Mock configuration
const mockConfig = {
  domain: 'test-tenant.auth0.com',
  audience: 'https://api.test.com',
  issuer: 'https://test-tenant.auth0.com/',
};

// Create a mock JWT validator that validates tokens using mock config
const createMockValidator = (): JWTValidator => ({
  validateToken: async (token: string) => {
    if (token === 'invalid-token') {
      return { valid: false, error: 'Invalid token format' };
    }
    try {
      const parts = token.split('.');
      if (parts.length !== 3) {
        return { valid: false, error: 'Invalid token format' };
      }
      const payload: any = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
      if (payload.iss !== mockConfig.issuer) {
        return { valid: false, error: 'Invalid issuer' };
      }
      const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
      if (!aud.includes(mockConfig.audience)) {
        return { valid: false, error: 'Invalid audience' };
      }
      if (payload.exp < Math.floor(Date.now() / 1000)) {
        return { valid: false, error: 'Token expired', userId: payload.sub, expiresAt: new Date(payload.exp * 1000) };
      }
      return { valid: true, userId: payload.sub, expiresAt: new Date(payload.exp * 1000) };
    } catch {
      return { valid: false, error: 'Invalid token format' };
    }
  },
});

describe('JWTValidationMiddleware', () => {
  let middleware: JWTValidationMiddleware;

  beforeEach(() => {
    middleware = new JWTValidationMiddleware(createMockValidator());
  });

  describe('validateToken', () => {
    it('should reject invalid token format', async () => {
      const result = await middleware.validateToken('invalid-token');
      
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Invalid token format');
    });

    it('should reject token with invalid issuer', async () => {
      // Create a token with wrong issuer
      const token = createMockToken({
        iss: 'https://wrong-issuer.com/',
        aud: mockConfig.audience,
        sub: 'user123',
        exp: Math.floor(Date.now() / 1000) + 3600,
      });

      const result = await middleware.validateToken(token);
      
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Invalid issuer');
    });

    it('should reject token with invalid audience', async () => {
      const token = createMockToken({
        iss: mockConfig.issuer,
        aud: 'https://wrong-audience.com',
        sub: 'user123',
        exp: Math.floor(Date.now() / 1000) + 3600,
      });

      const result = await middleware.validateToken(token);
      
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Invalid audience');
    });

    it('should detect expired tokens', async () => {
      const token = createMockToken({
        iss: mockConfig.issuer,
        aud: mockConfig.audience,
        sub: 'user123',
        exp: Math.floor(Date.now() / 1000) - 3600, // Expired 1 hour ago
      });

      const result = await middleware.validateToken(token);
      
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Token expired');
      expect(result.userId).toBe('user123');
      expect(result.expiresAt).toBeDefined();
    });

    it('should cache validation results', async () => {
      const token = createValidMockToken();

      // First validation
      const result1 = await middleware.validateToken(token);
      
      // Second validation (should use cache)
      const result2 = await middleware.validateToken(token);
      
      expect(result1).toEqual(result2);
    });
  });

  describe('getUserContext', () => {
    it('should extract user context from token', async () => {
      const token = createValidMockToken({
        'https://CloudToLocalLLM.com/tier': 'premium',
        'https://CloudToLocalLLM.com/permissions': ['read', 'write'],
      });

      const context = await middleware.getUserContext(token);
      
      expect(context.userId).toBe('user123');
      expect(context.tier).toBe(UserTier.PREMIUM);
      expect(context.permissions).toContain('read');
      expect(context.permissions).toContain('write');
      expect(context.rateLimit.requestsPerMinute).toBe(300);
    });

    it('should default to free tier if not specified', async () => {
      const token = createValidMockToken();

      const context = await middleware.getUserContext(token);
      
      expect(context.tier).toBe(UserTier.FREE);
      expect(context.rateLimit.requestsPerMinute).toBe(100);
    });

    it('should throw error for invalid token', async () => {
      await expect(
        middleware.getUserContext('invalid-token')
      ).rejects.toThrow('Invalid token');
    });
  });

  describe('logAuthAttempt', () => {
    it('should log authentication attempts', () => {
      const consoleSpy = jest.spyOn(console, 'info');

      middleware.logAuthAttempt('user123', true);
      
      expect(consoleSpy).toHaveBeenCalled();
      const output = consoleSpy.mock.calls[0][0] as string;
      expect(output).toContain('user123');
      expect(output).toContain('Auth attempt');
    });

    it('should log failed attempts with reason', () => {
      const consoleSpy = jest.spyOn(console, 'info');

      middleware.logAuthAttempt('user123', false, 'Invalid password');
      
      expect(consoleSpy).toHaveBeenCalled();
      const lastCall = consoleSpy.mock.calls[consoleSpy.mock.calls.length - 1][0] as string;
      expect(lastCall).toContain('Invalid password');
      expect(lastCall).toContain('Auth attempt');
    });
  });
});

describe('UserContextManager', () => {
  let manager: UserContextManager;

  beforeEach(() => {
    manager = new UserContextManager();
  });

  describe('extractUserContext', () => {
    it('should extract context from JWT payload', () => {
      const payload = {
        sub: 'user123',
        'https://CloudToLocalLLM.com/tier': 'enterprise',
        'https://CloudToLocalLLM.com/permissions': ['admin:read', 'admin:write'],
      };

      const context = manager.extractUserContext(payload);
      
      expect(context.userId).toBe('user123');
      expect(context.tier).toBe(UserTier.ENTERPRISE);
      expect(context.permissions).toContain('admin:read');
      expect(context.rateLimit.requestsPerMinute).toBe(1000);
    });

    it('should cache extracted contexts', () => {
      const payload = {
        sub: 'user123',
        'https://CloudToLocalLLM.com/tier': 'premium',
      };

      const context1 = manager.extractUserContext(payload);
      const context2 = manager.extractUserContext(payload);
      
      expect(context1).toBe(context2); // Same object reference (cached)
    });
  });

  describe('hasPermission', () => {
    it('should check if user has permission', () => {
      const context = {
        userId: 'user123',
        tier: UserTier.PREMIUM,
        permissions: ['read', 'write'],
        rateLimit: { requestsPerMinute: 300, maxConcurrentConnections: 5, maxQueueSize: 200 },
      };

      expect(manager.hasPermission(context, 'read')).toBe(true);
      expect(manager.hasPermission(context, 'write')).toBe(true);
      expect(manager.hasPermission(context, 'admin')).toBe(false);
    });
  });

  describe('hasAnyPermission', () => {
    it('should check if user has any of the permissions', () => {
      const context = {
        userId: 'user123',
        tier: UserTier.PREMIUM,
        permissions: ['read'],
        rateLimit: { requestsPerMinute: 300, maxConcurrentConnections: 5, maxQueueSize: 200 },
      };

      expect(manager.hasAnyPermission(context, ['read', 'write'])).toBe(true);
      expect(manager.hasAnyPermission(context, ['write', 'admin'])).toBe(false);
    });
  });

  describe('getFeatureFlags', () => {
    it('should return correct flags for free tier', () => {
      const flags = manager.getFeatureFlags(UserTier.FREE);
      
      expect(flags.advancedMetrics).toBe(false);
      expect(flags.prioritySupport).toBe(false);
      expect(flags.unlimitedModels).toBe(false);
    });

    it('should return correct flags for premium tier', () => {
      const flags = manager.getFeatureFlags(UserTier.PREMIUM);
      
      expect(flags.advancedMetrics).toBe(true);
      expect(flags.prioritySupport).toBe(true);
      expect(flags.unlimitedModels).toBe(true);
      expect(flags.dedicatedResources).toBe(false);
    });

    it('should return correct flags for enterprise tier', () => {
      const flags = manager.getFeatureFlags(UserTier.ENTERPRISE);
      
      expect(flags.advancedMetrics).toBe(true);
      expect(flags.prioritySupport).toBe(true);
      expect(flags.customIntegrations).toBe(true);
      expect(flags.dedicatedResources).toBe(true);
    });
  });
});

describe('AuthAuditLogger', () => {
  let logger: AuthAuditLogger;

  beforeEach(() => {
    logger = new AuthAuditLogger();
  });

  describe('logAuthAttempt', () => {
    it('should log authentication attempts', () => {
      const consoleSpy = jest.spyOn(console, 'info');

      logger.logAuthAttempt('user123', '192.168.1.1', true);
      
      expect(consoleSpy).toHaveBeenCalled();
    });

    it('should track failed attempts', () => {
      logger.logAuthAttempt('user123', '192.168.1.1', false, 'Invalid password');
      
      const failures = logger.getRecentFailures('user123');
      expect(failures.length).toBe(1);
      expect(failures[0].reason).toBe('Invalid password');
    });
  });

  describe('brute force detection', () => {
    it('should detect brute force attacks by IP', () => {
      const ip = '192.168.1.1';

      // Simulate 5 failed attempts
      for (let i = 0; i < 5; i++) {
        logger.logAuthAttempt('user123', ip, false, 'Invalid password');
      }

      expect(logger.isIPBlocked(ip)).toBe(true);
    });

    it('should detect distributed attacks', () => {
      const userId = 'user123';

      // Simulate 10 failed attempts from different IPs
      for (let i = 0; i < 10; i++) {
        logger.logAuthAttempt(userId, `192.168.1.${i}`, false, 'Invalid password');
      }

      expect(logger.isUserBlocked(userId)).toBe(true);
    });

    it('should clear tracking on successful auth', () => {
      const ip = '192.168.1.1';

      // Failed attempts
      for (let i = 0; i < 3; i++) {
        logger.logAuthAttempt('user123', ip, false);
      }

      // Successful auth
      logger.logAuthSuccess('user123', ip);

      expect(logger.isIPBlocked(ip)).toBe(false);
    });
  });

  describe('security alerts', () => {
    it('should emit security alerts for brute force', (done) => {
      logger.onSecurityAlert((alert) => {
        expect(alert.type).toBe('brute_force');
        expect(alert.severity).toBe('high');
        done();
      });

      // Trigger brute force detection
      for (let i = 0; i < 5; i++) {
        logger.logAuthAttempt('user123', '192.168.1.1', false);
      }
    });
  });

  describe('getAuthStats', () => {
    it('should calculate authentication statistics', () => {
      // Log some attempts
      logger.logAuthAttempt('user1', '192.168.1.1', true);
      logger.logAuthAttempt('user2', '192.168.1.2', true);
      logger.logAuthAttempt('user3', '192.168.1.3', false);

      const stats = logger.getAuthStats();
      
      expect(stats.totalAttempts).toBe(3);
      expect(stats.successfulAttempts).toBe(2);
      expect(stats.failedAttempts).toBe(1);
      expect(stats.successRate).toBeCloseTo(0.667, 2);
      expect(stats.uniqueUsers).toBe(3);
      expect(stats.uniqueIPs).toBe(3);
    });
  });

  describe('generateAuditReport', () => {
    it('should generate comprehensive audit report', () => {
      const now = new Date();
      const startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const endDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

      // Log some attempts (3 failures from same IP for suspiciousIPs threshold)
      logger.logAuthAttempt('user1', '192.168.1.1', true);
      logger.logAuthAttempt('user2', '192.168.1.2', false, 'Invalid password');
      logger.logAuthAttempt('user2', '192.168.1.2', false, 'Invalid password');
      logger.logAuthAttempt('user2', '192.168.1.2', false, 'Invalid password');
      logger.logAuthAttempt('user3', '192.168.1.3', false, 'Token expired');

      const report = logger.generateAuditReport(startDate, endDate);
      
      expect(report.stats.totalAttempts).toBeGreaterThan(0);
      expect(report.topFailureReasons.length).toBeGreaterThan(0);
      expect(report.suspiciousIPs.length).toBeGreaterThan(0);
    });
  });
});

// Helper functions for creating mock tokens
function createMockToken(payload: any): string {
  const header = { alg: 'RS256', typ: 'JWT', kid: 'test-key' };
  
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = 'mock-signature';
  
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function createValidMockToken(customClaims: any = {}): string {
  return createMockToken({
    iss: mockConfig.issuer,
    aud: mockConfig.audience,
    sub: 'user123',
    exp: Math.floor(Date.now() / 1000) + 3600,
    iat: Math.floor(Date.now() / 1000),
    ...customClaims,
  });
}

function base64UrlEncode(str: string): string {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}
