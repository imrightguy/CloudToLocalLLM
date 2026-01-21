/**
 * Admin Management API Routes (Super Admin Only)
 *
 * Provides secure administrative endpoints for managing administrator accounts:
 * - List all administrators with their roles
 * - Assign admin roles to users
 * - Revoke admin roles from users
 *
 * Security Features:
 * - Super Admin authentication required
 * - Comprehensive audit logging
 * - Input validation and sanitization
 * - Role assignment history tracking
 */

import express from 'express';
import { adminAuth, requireSuperAdmin } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import { getPool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/admins
 * List all administrators with their roles and activity summary
 *
 * Requires: Super Admin role
 *
 * Response:
 * {
 *   admins: [
 *     {
 *       userId: string,
 *       email: string,
 *       username: string,
 *       roles: [
 *         {
 *           role: string,
 *           grantedBy: string,
 *           grantedByEmail: string,
 *           grantedAt: timestamp,
 *           revokedAt: timestamp | null,
 *           isActive: boolean
 *         }
 *       ],
 *       activitySummary: {
 *         totalActions: number,
 *         lastActionAt: timestamp | null,
 *         recentActions: number (last 30 days)
 *       }
 *     }
 *   ],
 *   total: number
 * }
 */
router.get(
  '/',
  adminReadOnlyLimiter,
  adminAuth(),
  requireSuperAdmin,
  async (req, res) => {
    try {
      const pool = getPool();

      logger.info('📋 [AdminManagement] Listing all administrators', {
        requestedBy: req.adminUser.email,
      });

      // Query all administrators with their roles and activity summary
      const result = await pool.query(`
      SELECT 
        u.id as user_id,
        u.email,
        u.username,
        u.created_at as user_created_at,
        json_agg(
          json_build_object(
            'role', ar.role,
            'grantedBy', ar.granted_by,
            'grantedByEmail', granter.email,
            'grantedAt', ar.granted_at,
            'revokedAt', ar.revoked_at,
            'isActive', ar.is_active
          ) ORDER BY ar.granted_at DESC
        ) FILTER (WHERE ar.id IS NOT NULL) as roles,
        COUNT(DISTINCT aal.id) as total_actions,
        MAX(aal.created_at) as last_action_at,
        COUNT(DISTINCT aal.id) FILTER (WHERE aal.created_at >= NOW() - INTERVAL '30 days') as recent_actions
      FROM users u
      INNER JOIN admin_roles ar ON u.id = ar.user_id
      LEFT JOIN users granter ON ar.granted_by = granter.id
      LEFT JOIN admin_audit_logs aal ON u.id = aal.admin_user_id
      GROUP BY u.id, u.email, u.username, u.created_at
      ORDER BY u.email ASC
    `);

      const admins = result.rows.map((row) => ({
        userId: row.user_id,
        email: row.email,
        username: row.username,
        userCreatedAt: row.user_created_at,
        roles: row.roles || [],
        activitySummary: {
          totalActions: parseInt(row.total_actions) || 0,
          lastActionAt: row.last_action_at,
          recentActions: parseInt(row.recent_actions) || 0,
        },
      }));

      logger.info('✅ [AdminManagement] Administrators listed successfully', {
        count: admins.length,
        requestedBy: req.adminUser.email,
      });

      res.json({
        admins,
        total: admins.length,
      });
    } catch (error) {
      logger.error('🔴 [AdminManagement] Failed to list administrators', {
        error: error.message,
        stack: error.stack,
        requestedBy: req.adminUser?.email,
      });

      res.status(500).json({
        error: 'Failed to list administrators',
        code: 'LIST_ADMINS_FAILED',
        message: error.message,
      });
    }
  }
);

/**
 * POST /api/admin/admins
 * Assign admin role to a user
 *
 * Requires: Super Admin role
 *
 * Request Body:
 * {
 *   email: string (required) - Email of user to make admin
 *   role: string (required) - Role to assign (support_admin or finance_admin)
 * }
 *
 * Response:
 * {
 *   success: boolean,
 *   message: string,
 *   admin: {
 *     userId: string,
 *     email: string,
 *     role: string,
 *     grantedBy: string,
 *     grantedAt: timestamp
 *   }
 * }
 */
router.post(
  '/',
  adminRateLimiter,
  adminAuth(),
  requireSuperAdmin,
  async (req, res) => {
    try {
      const pool = getPool();
      const { email, role } = req.body;

      // Validate required fields
      if (!email || !role) {
        return res.status(400).json({
          error: 'Missing required fields',
          code: 'MISSING_FIELDS',
          message: 'Email and role are required',
        });
      }

      // Validate role
      const validRoles = ['support_admin', 'finance_admin'];
      if (!validRoles.includes(role)) {
        return res.status(400).json({
          error: 'Invalid role',
          code: 'INVALID_ROLE',
          message: `Role must be one of: ${validRoles.join(', ')}`,
        });
      }

      logger.info('👤 [AdminManagement] Assigning admin role', {
        email,
        role,
        grantedBy: req.adminUser.email,
      });

      // Search for user by email
      const userResult = await pool.query(
        'SELECT id, email, username FROM users WHERE email = $1',
        [email.toLowerCase()]
      );

      if (userResult.rows.length === 0) {
        logger.warn('⚠️ [AdminManagement] User not found', {
          email,
          requestedBy: req.adminUser.email,
        });
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
          message: `No user found with email: ${email}`,
        });
      }

      const user = userResult.rows[0];

      // Check if user already has this role
      const existingRoleResult = await pool.query(
        'SELECT * FROM admin_roles WHERE user_id = $1 AND role = $2 AND is_active = true',
        [user.id, role]
      );

      if (existingRoleResult.rows.length > 0) {
        logger.warn('⚠️ [AdminManagement] User already has this role', {
          userId: user.id,
          email: user.email,
          role,
        });
        return res.status(409).json({
          error: 'Role already assigned',
          code: 'ROLE_ALREADY_ASSIGNED',
          message: `User ${email} already has the ${role} role`,
        });
      }

      // Assign admin role
      const roleResult = await pool.query(
        `INSERT INTO admin_roles (user_id, role, granted_by, granted_at, is_active)
       VALUES ($1, $2, $3, NOW(), true)
       RETURNING *`,
        [user.id, role, req.adminUser.id]
      );

      const assignedRole = roleResult.rows[0];

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'admin_role_assigned',
        resourceType: 'admin_role',
        resourceId: assignedRole.id,
        affectedUserId: user.id,
        details: {
          email: user.email,
          role,
          grantedBy: req.adminUser.email,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminManagement] Admin role assigned successfully', {
        userId: user.id,
        email: user.email,
        role,
        grantedBy: req.adminUser.email,
      });

      res.status(201).json({
        success: true,
        message: `Admin role ${role} assigned to ${email}`,
        admin: {
          userId: user.id,
          email: user.email,
          username: user.username,
          role,
          grantedBy: req.adminUser.id,
          grantedByEmail: req.adminUser.email,
          grantedAt: assignedRole.granted_at,
        },
      });
    } catch (error) {
      logger.error('🔴 [AdminManagement] Failed to assign admin role', {
        error: error.message,
        stack: error.stack,
        email: req.body?.email,
        role: req.body?.role,
        requestedBy: req.adminUser?.email,
      });

      res.status(500).json({
        error: 'Failed to assign admin role',
        code: 'ASSIGN_ROLE_FAILED',
        message: error.message,
      });
    }
  }
);

/**
 * DELETE /api/admin/admins/:userId/roles/:role
 * Revoke admin role from a user
 *
 * Requires: Super Admin role
 *
 * URL Parameters:
 * - userId: ID of the user to revoke role from
 * - role: Role to revoke (super_admin, support_admin, or finance_admin)
 *
 * Response:
 * {
 *   success: boolean,
 *   message: string,
 *   revokedRole: {
 *     userId: string,
 *     email: string,
 *     role: string,
 *     revokedBy: string,
 *     revokedAt: timestamp
 *   }
 * }
 */
router.delete(
  '/:userId/roles/:role',
  adminRateLimiter,
  adminAuth(),
  requireSuperAdmin,
  async (req, res) => {
    try {
      const pool = getPool();
      const { userId, role } = req.params;

      // Validate role
      const validRoles = ['super_admin', 'support_admin', 'finance_admin'];
      if (!validRoles.includes(role)) {
        return res.status(400).json({
          error: 'Invalid role',
          code: 'INVALID_ROLE',
          message: `Role must be one of: ${validRoles.join(', ')}`,
        });
      }

      logger.info('🚫 [AdminManagement] Revoking admin role', {
        userId,
        role,
        revokedBy: req.adminUser.email,
      });

      // Get user information
      const userResult = await pool.query(
        'SELECT id, email, username FROM users WHERE id = $1',
        [userId]
      );

      if (userResult.rows.length === 0) {
        logger.warn('⚠️ [AdminManagement] User not found', {
          userId,
          requestedBy: req.adminUser.email,
        });
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
          message: `No user found with ID: ${userId}`,
        });
      }

      const user = userResult.rows[0];

      // Prevent revoking own Super Admin role
      if (userId === req.adminUser.id && role === 'super_admin') {
        logger.warn('⚠️ [AdminManagement] Cannot revoke own Super Admin role', {
          userId,
          email: user.email,
        });
        return res.status(403).json({
          error: 'Cannot revoke own Super Admin role',
          code: 'CANNOT_REVOKE_OWN_SUPER_ADMIN',
          message: 'You cannot revoke your own Super Admin role',
        });
      }

      // Check if user has this active role
      const existingRoleResult = await pool.query(
        'SELECT * FROM admin_roles WHERE user_id = $1 AND role = $2 AND is_active = true',
        [userId, role]
      );

      if (existingRoleResult.rows.length === 0) {
        logger.warn(
          '⚠️ [AdminManagement] User does not have this active role',
          {
            userId,
            email: user.email,
            role,
          }
        );
        return res.status(404).json({
          error: 'Role not found',
          code: 'ROLE_NOT_FOUND',
          message: `User ${user.email} does not have an active ${role} role`,
        });
      }

      const existingRole = existingRoleResult.rows[0];

      // Revoke admin role (set is_active to false and set revoked_at)
      await pool.query(
        `UPDATE admin_roles 
       SET is_active = false, revoked_at = NOW(), updated_at = NOW()
       WHERE id = $1`,
        [existingRole.id]
      );

      // Log admin action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'admin_role_revoked',
        resourceType: 'admin_role',
        resourceId: existingRole.id,
        affectedUserId: userId,
        details: {
          email: user.email,
          role,
          revokedBy: req.adminUser.email,
          previouslyGrantedBy: existingRole.granted_by,
          grantedAt: existingRole.granted_at,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminManagement] Admin role revoked successfully', {
        userId,
        email: user.email,
        role,
        revokedBy: req.adminUser.email,
      });

      res.json({
        success: true,
        message: `Admin role ${role} revoked from ${user.email}`,
        revokedRole: {
          userId: user.id,
          email: user.email,
          username: user.username,
          role,
          revokedBy: req.adminUser.id,
          revokedByEmail: req.adminUser.email,
          revokedAt: new Date().toISOString(),
        },
      });
    } catch (error) {
      logger.error('🔴 [AdminManagement] Failed to revoke admin role', {
        error: error.message,
        stack: error.stack,
        userId: req.params?.userId,
        role: req.params?.role,
        requestedBy: req.adminUser?.email,
      });

      res.status(500).json({
        error: 'Failed to revoke admin role',
        code: 'REVOKE_ROLE_FAILED',
        message: error.message,
      });
    }
  }
);

export default router;
