/**
 * Role-Based Access Control (RBAC) Middleware
 *
 * Provides comprehensive role-based access control for API endpoints
 * with permission validation and role definitions.
 *
 * Validates: Requirements 2.3, 2.5
 * - Support role-based access control (RBAC) for admin operations
 * - Validate user permissions before allowing operations
 */

import logger from '../logger.js';

/**
 * Role Definitions
 * Defines all available roles in the system
 */
export const ROLES = {
  SUPER_ADMIN: 'super_admin',
  SUPPORT_ADMIN: 'support_admin',
  FINANCE_ADMIN: 'finance_admin',
  USER: 'user',
  PREMIUM_USER: 'premium_user',
  ENTERPRISE_USER: 'enterprise_user',
};

/**
 * Permission Definitions
 * Defines all available permissions in the system
 */
export const PERMISSIONS = {
  // User management
  VIEW_USERS: 'view_users',
  EDIT_USERS: 'edit_users',
  DELETE_USERS: 'delete_users',
  SUSPEND_USERS: 'suspend_users',
  MANAGE_USER_TIERS: 'manage_user_tiers',

  // Session management
  VIEW_SESSIONS: 'view_sessions',
  TERMINATE_SESSIONS: 'terminate_sessions',

  // Tunnel management
  CREATE_TUNNELS: 'create_tunnels',
  EDIT_TUNNELS: 'edit_tunnels',
  DELETE_TUNNELS: 'delete_tunnels',
  VIEW_TUNNELS: 'view_tunnels',
  MANAGE_TUNNEL_SHARING: 'manage_tunnel_sharing',

  // Proxy management
  MANAGE_PROXY: 'manage_proxy',
  VIEW_PROXY_METRICS: 'view_proxy_metrics',

  // Payment and billing
  VIEW_PAYMENTS: 'view_payments',
  PROCESS_REFUNDS: 'process_refunds',
  VIEW_SUBSCRIPTIONS: 'view_subscriptions',
  EDIT_SUBSCRIPTIONS: 'edit_subscriptions',

  // Reporting and analytics
  VIEW_REPORTS: 'view_reports',
  EXPORT_REPORTS: 'export_reports',
  VIEW_AUDIT_LOGS: 'view_audit_logs',

  // System configuration
  MANAGE_SYSTEM_CONFIG: 'manage_system_config',
  VIEW_SYSTEM_METRICS: 'view_system_metrics',
  MANAGE_EMAIL_CONFIG: 'manage_email_config',
  VIEW_EMAIL_CONFIG: 'view_email_config',

  // Webhook management
  MANAGE_WEBHOOKS: 'manage_webhooks',
  VIEW_WEBHOOKS: 'view_webhooks',
};

/**
 * Role to Permissions Mapping
 * Defines which permissions each role has
 */
export const ROLE_PERMISSIONS = {
  [ROLES.SUPER_ADMIN]: [
    // Super admin has all permissions
    '*',
  ],
  [ROLES.SUPPORT_ADMIN]: [
    PERMISSIONS.VIEW_USERS,
    PERMISSIONS.EDIT_USERS,
    PERMISSIONS.SUSPEND_USERS,
    PERMISSIONS.VIEW_SESSIONS,
    PERMISSIONS.TERMINATE_SESSIONS,
    PERMISSIONS.VIEW_PAYMENTS,
    PERMISSIONS.VIEW_AUDIT_LOGS,
    PERMISSIONS.VIEW_EMAIL_CONFIG,
    PERMISSIONS.MANAGE_EMAIL_CONFIG,
    PERMISSIONS.VIEW_SYSTEM_METRICS,
    PERMISSIONS.VIEW_WEBHOOKS,
  ],
  [ROLES.FINANCE_ADMIN]: [
    PERMISSIONS.VIEW_USERS,
    PERMISSIONS.VIEW_PAYMENTS,
    PERMISSIONS.PROCESS_REFUNDS,
    PERMISSIONS.VIEW_SUBSCRIPTIONS,
    PERMISSIONS.EDIT_SUBSCRIPTIONS,
    PERMISSIONS.VIEW_REPORTS,
    PERMISSIONS.EXPORT_REPORTS,
    PERMISSIONS.VIEW_AUDIT_LOGS,
  ],
  [ROLES.USER]: [
    PERMISSIONS.CREATE_TUNNELS,
    PERMISSIONS.EDIT_TUNNELS,
    PERMISSIONS.DELETE_TUNNELS,
    PERMISSIONS.VIEW_TUNNELS,
    PERMISSIONS.MANAGE_TUNNEL_SHARING,
    PERMISSIONS.VIEW_PAYMENTS,
    PERMISSIONS.VIEW_SUBSCRIPTIONS,
  ],
  [ROLES.PREMIUM_USER]: [
    PERMISSIONS.CREATE_TUNNELS,
    PERMISSIONS.EDIT_TUNNELS,
    PERMISSIONS.DELETE_TUNNELS,
    PERMISSIONS.VIEW_TUNNELS,
    PERMISSIONS.MANAGE_TUNNEL_SHARING,
    PERMISSIONS.MANAGE_PROXY,
    PERMISSIONS.VIEW_PROXY_METRICS,
    PERMISSIONS.VIEW_PAYMENTS,
    PERMISSIONS.VIEW_SUBSCRIPTIONS,
    PERMISSIONS.VIEW_REPORTS,
  ],
  [ROLES.ENTERPRISE_USER]: [
    PERMISSIONS.CREATE_TUNNELS,
    PERMISSIONS.EDIT_TUNNELS,
    PERMISSIONS.DELETE_TUNNELS,
    PERMISSIONS.VIEW_TUNNELS,
    PERMISSIONS.MANAGE_TUNNEL_SHARING,
    PERMISSIONS.MANAGE_PROXY,
    PERMISSIONS.VIEW_PROXY_METRICS,
    PERMISSIONS.VIEW_PAYMENTS,
    PERMISSIONS.VIEW_SUBSCRIPTIONS,
    PERMISSIONS.VIEW_REPORTS,
    PERMISSIONS.EXPORT_REPORTS,
    PERMISSIONS.MANAGE_WEBHOOKS,
    PERMISSIONS.VIEW_WEBHOOKS,
  ],
};

/**
 * Check if user has required permission
 * @param {Array<string>} userRoles - User's roles
 * @param {string|Array<string>} requiredPermissions - Required permission(s)
 * @returns {boolean} True if user has permission
 */
export function hasPermission(userRoles, requiredPermissions) {
  if (!userRoles || userRoles.length === 0) {
    return false;
  }

  // Normalize to array
  const permissions = Array.isArray(requiredPermissions)
    ? requiredPermissions
    : [requiredPermissions];

  // Get all permissions for user's roles
  const userPermissions = userRoles.flatMap(
    (role) => ROLE_PERMISSIONS[role] || [],
  );

  // Check for super admin wildcard
  if (userPermissions.includes('*')) {
    return true;
  }

  // Check if user has all required permissions
  return permissions.every((perm) => userPermissions.includes(perm));
}

/**
 * Check if user has any of the required permissions
 * @param {Array<string>} userRoles - User's roles
 * @param {Array<string>} requiredPermissions - Required permissions (any one)
 * @returns {boolean} True if user has any permission
 */
export function hasAnyPermission(userRoles, requiredPermissions) {
  if (!userRoles || userRoles.length === 0) {
    return false;
  }

  const permissions = Array.isArray(requiredPermissions)
    ? requiredPermissions
    : [requiredPermissions];

  const userPermissions = userRoles.flatMap(
    (role) => ROLE_PERMISSIONS[role] || [],
  );

  // Check for super admin wildcard
  if (userPermissions.includes('*')) {
    return true;
  }

  // Check if user has any required permission
  return permissions.some((perm) => userPermissions.includes(perm));
}

/**
 * RBAC Middleware Factory
 * Creates middleware that checks for required permissions
 *
 * @param {string|Array<string>} requiredPermissions - Required permission(s)
 * @param {Object} options - Options
 * @param {boolean} options.requireAll - Require all permissions (default: true)
 * @returns {Function} Express middleware function
 */
export function requirePermission(requiredPermissions, options = {}) {
  const { requireAll = true } = options;

  return (req, res, next) => {
    try {
      // Check if user is authenticated
      if (!req.user) {
        logger.warn('[RBAC] Permission check failed - user not authenticated', {
          path: req.path,
          method: req.method,
          ip: req.ip,
        });

        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
        });
      }

      // Get user roles from request
      const userRoles = req.userRoles || [];

      // Check permissions
      const hasPerms = requireAll
        ? hasPermission(userRoles, requiredPermissions)
        : hasAnyPermission(userRoles, requiredPermissions);

      if (!hasPerms) {
        logger.warn('[RBAC] Permission denied', {
          userId: req.user.sub,
          userRoles,
          requiredPermissions,
          path: req.path,
          method: req.method,
          ip: req.ip,
        });

        return res.status(403).json({
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          required: requiredPermissions,
        });
      }

      logger.debug('[RBAC] Permission granted', {
        userId: req.user.sub,
        userRoles,
        requiredPermissions,
      });

      next();
    } catch (error) {
      logger.error('[RBAC] Permission check error', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'Permission check failed',
        code: 'PERMISSION_CHECK_ERROR',
      });
    }
  };
}

/**
 * RBAC Authorization Middleware
 * Attaches user roles to request based on user tier and admin status
 *
 * Should be applied after authentication middleware
 */
export function authorizeRBAC(req, res, next) {
  try {
    if (!req.user) {
      // No user authenticated, continue without roles
      req.userRoles = [];
      return next();
    }

    const userRoles = [];

    // Check for admin roles from JWT metadata
    const userMetadata =
      req.user['https://cloudtolocalllm.com/user_metadata'] || {};
    const appMetadata =
      req.user['https://cloudtolocalllm.com/app_metadata'] || {};
    const jwtRoles = req.user['https://cloudtolocalllm.online/roles'] || [];

    // Add admin roles if present
    if (
      userMetadata.role === 'super_admin' ||
      appMetadata.role === 'super_admin'
    ) {
      userRoles.push(ROLES.SUPER_ADMIN);
    } else if (
      userMetadata.role === 'support_admin' ||
      appMetadata.role === 'support_admin'
    ) {
      userRoles.push(ROLES.SUPPORT_ADMIN);
    } else if (
      userMetadata.role === 'finance_admin' ||
      appMetadata.role === 'finance_admin'
    ) {
      userRoles.push(ROLES.FINANCE_ADMIN);
    }

    // Add roles from JWT roles array
    if (Array.isArray(jwtRoles)) {
      jwtRoles.forEach((role) => {
        if (Object.values(ROLES).includes(role) && !userRoles.includes(role)) {
          userRoles.push(role);
        }
      });
    }

    // Add user tier-based roles if not admin
    if (userRoles.length === 0) {
      const userTier = req.user['https://cloudtolocalllm.com/tier'] || 'free';

      if (userTier === 'premium') {
        userRoles.push(ROLES.PREMIUM_USER);
      } else if (userTier === 'enterprise') {
        userRoles.push(ROLES.ENTERPRISE_USER);
      } else {
        userRoles.push(ROLES.USER);
      }
    }

    // Attach roles to request
    req.userRoles = userRoles;

    logger.debug('[RBAC] User roles assigned', {
      userId: req.user.sub,
      roles: userRoles,
    });

    next();
  } catch (error) {
    logger.error('[RBAC] Authorization failed', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Authorization failed',
      code: 'AUTHORIZATION_ERROR',
    });
  }
}

/**
 * Require specific role
 * @param {string|Array<string>} requiredRoles - Required role(s)
 * @param {Object} options - Options
 * @param {boolean} options.requireAll - Require all roles (default: true)
 * @returns {Function} Express middleware function
 */
export function requireRole(requiredRoles, options = {}) {
  const { requireAll = true } = options;
  const roles = Array.isArray(requiredRoles) ? requiredRoles : [requiredRoles];

  return (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
        });
      }

      const userRoles = req.userRoles || [];

      const hasRole = requireAll
        ? roles.every((role) => userRoles.includes(role))
        : roles.some((role) => userRoles.includes(role));

      if (!hasRole) {
        logger.warn('[RBAC] Role check failed', {
          userId: req.user.sub,
          userRoles,
          requiredRoles: roles,
          path: req.path,
        });

        return res.status(403).json({
          error: 'Insufficient role',
          code: 'INSUFFICIENT_ROLE',
          required: roles,
        });
      }

      logger.debug('[RBAC] Role check passed', {
        userId: req.user.sub,
        userRoles,
        requiredRoles: roles,
      });

      next();
    } catch (error) {
      logger.error('[RBAC] Role check error', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'Role check failed',
        code: 'ROLE_CHECK_ERROR',
      });
    }
  };
}

/**
 * Require admin role (any admin role)
 * @returns {Function} Express middleware function
 */
export function requireAdmin() {
  return requireRole(
    [ROLES.SUPER_ADMIN, ROLES.SUPPORT_ADMIN, ROLES.FINANCE_ADMIN],
    { requireAll: false },
  );
}

/**
 * Require super admin role
 * @returns {Function} Express middleware function
 */
export function requireSuperAdmin() {
  return requireRole(ROLES.SUPER_ADMIN);
}

export default {
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
};
