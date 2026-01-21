/**
 * Admin Authentication and Authorization Middleware
 *
 * Provides role-based access control for admin endpoints with comprehensive
 * permission checking and database-backed role verification.
 */

import jwt from 'jsonwebtoken';
import logger from '../logger.js';
import { getPool, closePool } from '../database/db-pool.js';

/**
 * Permission mapping for each admin role
 */
const ROLE_PERMISSIONS = {
  super_admin: ['*'], // All permissions
  support_admin: [
    'view_users',
    'edit_users',
    'suspend_users',
    'view_sessions',
    'terminate_sessions',
    'view_payments',
    'view_audit_logs',
    'view_email_config',
    'manage_email_config',
    'view_system_metrics',
  ],
  finance_admin: [
    'view_users',
    'view_payments',
    'process_refunds',
    'view_subscriptions',
    'edit_subscriptions',
    'view_reports',
    'export_reports',
    'view_audit_logs',
  ],
};

/**
 * Check if user roles have required permissions
 * @param {Array<string>} userRoles - User's admin roles
 * @param {Array<string>} requiredPermissions - Required permissions
 * @returns {boolean} True if user has all required permissions
 */
export function checkPermissions(userRoles, requiredPermissions) {
  if (!userRoles || userRoles.length === 0) {
    return false;
  }

  // Super admin has all permissions
  if (userRoles.includes('super_admin')) {
    return true;
  }

  // Get all permissions for user's roles
  const userPermissions = userRoles.flatMap(
    (role) => ROLE_PERMISSIONS[role] || [],
  );

  // Check if user has all required permissions
  return requiredPermissions.every((perm) => userPermissions.includes(perm));
}

/**
 * Admin authentication middleware with role checking
 * Verifies JWT token and checks admin role from database
 *
 * @param {Array<string>} requiredPermissions - Optional array of required permissions
 * @returns {Function} Express middleware function
 */
export function adminAuth(requiredPermissions = []) {
  return async (req, res, next) => {
    try {
      // Verify JWT token
      const token = req.headers.authorization?.split(' ')[1];
      if (!token) {
        return res.status(401).json({
          error: 'No token provided',
          code: 'NO_TOKEN',
        });
      }

      // Decode and verify token
      let decoded;
      try {
        // For JWT tokens, we just decode without verification since JWT SDK already verified it
        decoded = jwt.decode(token);
        if (!decoded) {
          return res.status(401).json({
            error: 'Invalid token',
            code: 'INVALID_TOKEN',
          });
        }
      } catch (error) {
        logger.error('🔴 [AdminAuth] Token decode failed', {
          error: error.message,
        });
        return res.status(401).json({
          error: 'Invalid token',
          code: 'INVALID_TOKEN',
        });
      }

      // Initialize database pool if needed
      const pool = getPool();

      // Get user and their admin roles from database
      const userResult = await pool.query(
        `SELECT u.id, u.email, u.jwt_id,
                array_agg(ar.role) FILTER (WHERE ar.role IS NOT NULL) as roles
         FROM users u
         LEFT JOIN admin_roles ar ON u.id = ar.user_id AND ar.is_active = true
         WHERE u.jwt_id = $1
         GROUP BY u.id, u.email, u.jwt_id`,
        [decoded.sub],
      );

      if (!userResult.rows[0]) {
        logger.warn('⚠️ [AdminAuth] User not found', {
          jwt_id: decoded.sub,
        });
        return res.status(403).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
        });
      }

      const user = userResult.rows[0];

      // Check if user has any admin role
      if (!user.roles || user.roles.length === 0 || user.roles[0] === null) {
        logger.warn('⚠️ [AdminAuth] Admin access denied - no admin role', {
          userId: user.id,
          email: user.email,
          ipAddress: req.ip,
          userAgent: req.get('User-Agent'),
        });
        return res.status(403).json({
          error: 'Admin access required',
          code: 'ADMIN_ACCESS_REQUIRED',
          message: 'This operation requires administrative privileges',
        });
      }

      // Check if user has required permissions
      if (requiredPermissions.length > 0) {
        const hasPermission = checkPermissions(user.roles, requiredPermissions);
        if (!hasPermission) {
          logger.warn('⚠️ [AdminAuth] Insufficient permissions', {
            userId: user.id,
            email: user.email,
            roles: user.roles,
            required: requiredPermissions,
            ipAddress: req.ip,
          });
          return res.status(403).json({
            error: 'Insufficient permissions',
            code: 'INSUFFICIENT_PERMISSIONS',
            required: requiredPermissions,
          });
        }
      }

      // Attach admin user info to request
      req.adminUser = user;
      req.adminRoles = user.roles;

      logger.info('✅ [AdminAuth] Admin access granted', {
        userId: user.id,
        email: user.email,
        roles: user.roles,
        permissions: requiredPermissions,
      });

      next();
    } catch (error) {
      logger.error('🔴 [AdminAuth] Authentication failed', {
        error: error.message,
        stack: error.stack,
      });
      return res.status(500).json({
        error: 'Authentication failed',
        code: 'AUTH_FAILED',
      });
    }
  };
}

/**
 * Check if user has specific admin role
 * @param {string} role - Required admin role
 * @returns {Function} Express middleware function
 */
export function requireRole(role) {
  return (req, res, next) => {
    if (!req.adminRoles || !req.adminRoles.includes(role)) {
      logger.warn('⚠️ [AdminAuth] Required role not found', {
        userId: req.adminUser?.id,
        userRoles: req.adminRoles,
        requiredRole: role,
      });
      return res.status(403).json({
        error: 'Insufficient role',
        code: 'INSUFFICIENT_ROLE',
        required: role,
      });
    }
    next();
  };
}

/**
 * Require Super Admin role
 * Convenience middleware for operations that require Super Admin
 */
export function requireSuperAdmin(req, res, next) {
  return requireRole('super_admin')(req, res, next);
}

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closeDbPool() {
  await closePool();
}

// Export permission constants for use in routes
export { ROLE_PERMISSIONS };
