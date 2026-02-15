/**


 * RBAC Middleware Tests
 *
 * Tests for role-based access control middleware
 * Validates: Requirements 2.3, 2.5
 */

import { jest, describe, it, expect } from '@jest/globals';
import {
  ROLES,
  PERMISSIONS,
  ROLE_PERMISSIONS,
  hasPermission,
  hasAnyPermission,
  requirePermission,
  authorizeRBAC,
  requireRole,
  requireAdmin,
  requireSuperAdmin,
} from '../../services/api-backend/middleware/rbac.js';

describe('RBAC Middleware', () => {
  describe('hasPermission', () => {
    it('should return true if user has required permission', () => {
      const userRoles = [ROLES.SUPPORT_ADMIN];
      const result = hasPermission(userRoles, PERMISSIONS.VIEW_USERS);
      expect(result).toBe(true);
    });

    it('should return true if user has all required permissions', () => {
      const userRoles = [ROLES.SUPPORT_ADMIN];
      const result = hasPermission(userRoles, [
        PERMISSIONS.VIEW_USERS,
        PERMISSIONS.EDIT_USERS,
      ]);
      expect(result).toBe(true);
    });

    it('should return false if user lacks required permission', () => {
      const userRoles = [ROLES.USER];
      const result = hasPermission(userRoles, PERMISSIONS.MANAGE_SYSTEM_CONFIG);
      expect(result).toBe(false);
    });

    it('should return true for super admin with any permission', () => {
      const userRoles = [ROLES.SUPER_ADMIN];
      const result = hasPermission(userRoles, PERMISSIONS.MANAGE_SYSTEM_CONFIG);
      expect(result).toBe(true);
    });

    it('should return false for empty roles', () => {
      const result = hasPermission([], PERMISSIONS.VIEW_USERS);
      expect(result).toBe(false);
    });

    it('should return false for null roles', () => {
      const result = hasPermission(null, PERMISSIONS.VIEW_USERS);
      expect(result).toBe(false);
    });
  });

  describe('hasAnyPermission', () => {
    it('should return true if user has any required permission', () => {
      const userRoles = [ROLES.SUPPORT_ADMIN];
      const result = hasAnyPermission(userRoles, [
        PERMISSIONS.MANAGE_SYSTEM_CONFIG,
        PERMISSIONS.VIEW_USERS,
      ]);
      expect(result).toBe(true);
    });

    it('should return false if user has none of the required permissions', () => {
      const userRoles = [ROLES.USER];
      const result = hasAnyPermission(userRoles, [
        PERMISSIONS.MANAGE_SYSTEM_CONFIG,
        PERMISSIONS.PROCESS_REFUNDS,
      ]);
      expect(result).toBe(false);
    });

    it('should return true for super admin', () => {
      const userRoles = [ROLES.SUPER_ADMIN];
      const result = hasAnyPermission(userRoles, [
        PERMISSIONS.MANAGE_SYSTEM_CONFIG,
      ]);
      expect(result).toBe(true);
    });
  });

  describe('requirePermission middleware', () => {
    it('should call next if user has required permission', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPPORT_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requirePermission(PERMISSIONS.VIEW_USERS);
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should return 401 if user not authenticated', () => {
      const req = { user: null };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requirePermission(PERMISSIONS.VIEW_USERS);
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          code: 'AUTH_REQUIRED',
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 403 if user lacks required permission', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.USER],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requirePermission(PERMISSIONS.MANAGE_SYSTEM_CONFIG);
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          code: 'INSUFFICIENT_PERMISSIONS',
        }),
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should support multiple permissions with requireAll option', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPPORT_ADMIN],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requirePermission(
        [PERMISSIONS.VIEW_USERS, PERMISSIONS.EDIT_USERS],
        { requireAll: true },
      );
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should support multiple permissions with requireAll false', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.USER],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requirePermission(
        [PERMISSIONS.MANAGE_SYSTEM_CONFIG, PERMISSIONS.CREATE_TUNNELS],
        { requireAll: false },
      );
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });
  });

  describe('authorizeRBAC middleware', () => {
    it('should attach user roles based on admin metadata', () => {
      const req = {
        user: {
          sub: 'user123',
          'https://zoidbot.com/user_metadata': {
            role: 'super_admin',
          },
        },
      };
      const res = {};
      const next = jest.fn();

      authorizeRBAC(req, res, next);

      expect(req.userRoles).toContain(ROLES.SUPER_ADMIN);
      expect(next).toHaveBeenCalled();
    });

    it('should attach user roles based on tier', () => {
      const req = {
        user: {
          sub: 'user123',
          'https://zoidbot.com/tier': 'premium',
        },
      };
      const res = {};
      const next = jest.fn();

      authorizeRBAC(req, res, next);

      expect(req.userRoles).toContain(ROLES.PREMIUM_USER);
      expect(next).toHaveBeenCalled();
    });

    it('should default to USER role for free tier', () => {
      const req = {
        user: {
          sub: 'user123',
        },
      };
      const res = {};
      const next = jest.fn();

      authorizeRBAC(req, res, next);

      expect(req.userRoles).toContain(ROLES.USER);
      expect(next).toHaveBeenCalled();
    });

    it('should handle unauthenticated requests', () => {
      const req = { user: null };
      const res = {};
      const next = jest.fn();

      authorizeRBAC(req, res, next);

      expect(req.userRoles).toEqual([]);
      expect(next).toHaveBeenCalled();
    });

    it('should attach roles from JWT roles array', () => {
      const req = {
        user: {
          sub: 'user123',
          'https://zoidbot.online/roles': [ROLES.SUPPORT_ADMIN],
        },
      };
      const res = {};
      const next = jest.fn();

      authorizeRBAC(req, res, next);

      expect(req.userRoles).toContain(ROLES.SUPPORT_ADMIN);
      expect(next).toHaveBeenCalled();
    });
  });

  describe('requireRole middleware', () => {
    it('should call next if user has required role', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPER_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requireRole(ROLES.SUPER_ADMIN);
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should return 403 if user lacks required role', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.USER],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requireRole(ROLES.SUPER_ADMIN);
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          code: 'INSUFFICIENT_ROLE',
        }),
      );
    });

    it('should support multiple roles with requireAll false', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPPORT_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requireRole(
        [ROLES.SUPER_ADMIN, ROLES.SUPPORT_ADMIN],
        { requireAll: false },
      );
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });
  });

  describe('requireAdmin middleware', () => {
    it('should allow super admin', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPER_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requireAdmin();
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should allow support admin', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPPORT_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requireAdmin();
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should deny regular user', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.USER],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requireAdmin();
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
    });
  });

  describe('requireSuperAdmin middleware', () => {
    it('should allow super admin', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPER_ADMIN],
      };
      const res = {};
      const next = jest.fn();

      const middleware = requireSuperAdmin();
      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });

    it('should deny support admin', () => {
      const req = {
        user: { sub: 'user123' },
        userRoles: [ROLES.SUPPORT_ADMIN],
      };
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      const middleware = requireSuperAdmin();
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
    });
  });

  describe('Role Permissions Mapping', () => {
    it('should have all roles defined', () => {
      Object.values(ROLES).forEach((role) => {
        expect(ROLE_PERMISSIONS[role]).toBeDefined();
        expect(Array.isArray(ROLE_PERMISSIONS[role])).toBe(true);
      });
    });

    it('should have super admin with wildcard permission', () => {
      expect(ROLE_PERMISSIONS[ROLES.SUPER_ADMIN]).toContain('*');
    });

    it('should have support admin with appropriate permissions', () => {
      const supportAdminPerms = ROLE_PERMISSIONS[ROLES.SUPPORT_ADMIN];
      expect(supportAdminPerms).toContain(PERMISSIONS.VIEW_USERS);
      expect(supportAdminPerms).toContain(PERMISSIONS.EDIT_USERS);
      expect(supportAdminPerms).not.toContain(PERMISSIONS.PROCESS_REFUNDS);
    });

    it('should have finance admin with appropriate permissions', () => {
      const financeAdminPerms = ROLE_PERMISSIONS[ROLES.FINANCE_ADMIN];
      expect(financeAdminPerms).toContain(PERMISSIONS.VIEW_PAYMENTS);
      expect(financeAdminPerms).toContain(PERMISSIONS.PROCESS_REFUNDS);
      expect(financeAdminPerms).not.toContain(PERMISSIONS.MANAGE_SYSTEM_CONFIG);
    });

    it('should have user with appropriate permissions', () => {
      const userPerms = ROLE_PERMISSIONS[ROLES.USER];
      expect(userPerms).toContain(PERMISSIONS.CREATE_TUNNELS);
      expect(userPerms).toContain(PERMISSIONS.VIEW_TUNNELS);
      expect(userPerms).not.toContain(PERMISSIONS.MANAGE_SYSTEM_CONFIG);
    });

    it('should have premium user with more permissions than user', () => {
      const userPerms = ROLE_PERMISSIONS[ROLES.USER];
      const premiumPerms = ROLE_PERMISSIONS[ROLES.PREMIUM_USER];
      expect(premiumPerms.length).toBeGreaterThan(userPerms.length);
    });

    it('should have enterprise user with most permissions', () => {
      const userPerms = ROLE_PERMISSIONS[ROLES.USER];
      const enterprisePerms = ROLE_PERMISSIONS[ROLES.ENTERPRISE_USER];
      expect(enterprisePerms.length).toBeGreaterThan(userPerms.length);
    });
  });
});
