const bcrypt = require('bcryptjs');
const { createHash } = require('node:crypto');
const jwt = require('jsonwebtoken');
const {
  eq, and, ne, sql, desc,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const { usersTable, refreshTokensTable } = require('../database/schema');
const { generateAccessToken, generateRefreshToken } = require('../auth/jwt.middleware');
const { child } = require('../utils/logger');

const log = child({ controller: 'auth' });

const COMPANY_NAME = process.env.APP_COMPANY_NAME || 'ImmoGestion';

// ─── Refresh token handling ───────────────────────────────────────────────────
// Refresh tokens are NEVER stored in clear: a SQL dump must not be enough to
// hijack a session. We persist the SHA-256 hash and compare hashes on lookup.
const REFRESH_COOKIE_NAME = 'refreshToken';
const REFRESH_TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** SHA-256 hash of a refresh token, as stored/looked-up in the DB. */
const hashToken = (token) => createHash('sha256').update(token).digest('hex');

/** Cookie attributes shared by set/clear so the browser can match them. */
const refreshCookieOptions = () => ({
  httpOnly: true, // not reachable from JS → immune to XSS token theft
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  path: '/api/auth', // only sent to /api/auth/refresh and /api/auth/logout
});

/** Persist the refresh token to an HttpOnly cookie (web clients). */
const setRefreshCookie = (res, token) => {
  res.cookie(REFRESH_COOKIE_NAME, token, {
    ...refreshCookieOptions(),
    maxAge: REFRESH_TOKEN_TTL_MS,
  });
};

const clearRefreshCookie = (res) => {
  res.clearCookie(REFRESH_COOKIE_NAME, refreshCookieOptions());
};

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Strip passwordHash from a user row and attach the single-company profile contract. */
const sanitizeUser = (user) => {
  if (!user) {return null;}
  const { passwordHash: _passwordHash, ...safe } = user;
  return { ...safe, company: COMPANY_NAME };
};

/** Fields to return for user objects (excludes passwordHash) */
const userPublicFields = {
  id: usersTable.id,
  email: usersTable.email,
  firstName: usersTable.firstName,
  lastName: usersTable.lastName,
  phone: usersTable.phone,
  role: usersTable.role,
  isActive: usersTable.isActive,
  emailVerified: usersTable.emailVerified,
  tokenVersion: usersTable.tokenVersion,
  lastLogin: usersTable.lastLogin,
  createdAt: usersTable.createdAt,
  updatedAt: usersTable.updatedAt,
};

// ─── Auth: Register ─────────────────────────────────────────────────────────

const register = async (req, res) => {
  try {
    const {
      email, password, firstName, lastName, phone,
    } = req.body;

    if (!email || !password || !firstName || !lastName) {
      return res.status(400).json({
        success: false,
        error: { message: 'Email, password, firstName, and lastName are required', code: 'MISSING_REQUIRED_FIELDS' },
      });
    }

    // Check for existing user
    const existing = await db
      .select({ id: usersTable.id })
      .from(usersTable)
      .where(eq(usersTable.email, email.toLowerCase().trim()))
      .limit(1);

    // Do not reveal whether an email is already registered: returning a
    // distinct 409/USER_ALREADY_EXISTS lets an attacker enumerate valid
    // accounts. Respond with a neutral acknowledgement instead. (The legitimate
    // new-user path below still returns 201 + tokens for auto-login.)
    if (existing.length > 0) {
      return res.status(200).json({
        success: true,
        data: null,
        message: 'If this email is available, you will receive a confirmation shortly.',
      });
    }

    // Hash password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS, 10) || 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Insert user
    const created = await db
      .insert(usersTable)
      .values({
        email: email.toLowerCase().trim(),
        passwordHash,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone ? phone.trim() : null,
        role: 'user',
      })
      .returning(userPublicFields);

    if (!created.length) {
      return res.status(500).json({
        success: false,
        error: { message: 'User creation failed', code: 'USER_CREATION_FAILED' },
      });
    }

    const user = sanitizeUser(created[0]);

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Persist refresh token (hashed) and mirror it into an HttpOnly cookie.
    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

    setRefreshCookie(res, refreshToken);

    return res.status(201).json({
      success: true,
      data: {
        user,
        tokens: {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        },
      },
      message: 'User registered successfully',
    });
  } catch (error) {
    log.error('Registration error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Registration failed', code: 'REGISTRATION_FAILED' },
    });
  }
};

// ─── Auth: Login ────────────────────────────────────────────────────────────

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: { message: 'Email and password are required', code: 'MISSING_CREDENTIALS' },
      });
    }

    // Find user
    const rows = await db
      .select()
      .from(usersTable)
      .where(eq(usersTable.email, email.toLowerCase().trim()))
      .limit(1);

    if (!rows.length) {
      return res.status(401).json({
        success: false,
        error: { message: 'Invalid credentials', code: 'INVALID_CREDENTIALS' },
      });
    }

    const user = rows[0];

    // Check active
    if (!user.isActive) {
      return res.status(401).json({
        success: false,
        error: { message: 'Account is inactive', code: 'ACCOUNT_INACTIVE' },
      });
    }

    // Verify password
    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: { message: 'Invalid credentials', code: 'INVALID_CREDENTIALS' },
      });
    }

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Persist refresh token (hashed) and mirror it into an HttpOnly cookie.
    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

    setRefreshCookie(res, refreshToken);

    // Update lastLogin without blocking a successful login if audit metadata persistence fails.
    try {
      await db
        .update(usersTable)
        .set({ lastLogin: new Date() })
        .where(eq(usersTable.id, user.id));
    } catch (updateError) {
      log.warn('Failed to update lastLogin during login', {
        userId: user.id,
        error: updateError.message,
      });
    }

    const safeUser = sanitizeUser(user);

    return res.json({
      success: true,
      data: {
        user: safeUser,
        tokens: {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        },
      },
      message: 'Login successful',
    });
  } catch (error) {
    log.error('Login error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Login failed', code: 'LOGIN_FAILED' },
    });
  }
};

// ─── Auth: Refresh Access Token ─────────────────────────────────────────────

const refreshAccessToken = async (req, res) => {
  try {
    // Web clients send the token via the HttpOnly cookie; native clients,
    // which can't read it back, still pass it in the body.
    const refreshToken = (req.cookies && req.cookies[REFRESH_COOKIE_NAME]) || req.body.refreshToken;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: { message: 'Refresh token is required', code: 'REFRESH_TOKEN_REQUIRED' },
      });
    }

    // Verify the JWT signature/expiry BEFORE any DB lookup. Without this the
    // refresh token was treated as an opaque string and never authenticated.
    try {
      jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET, { algorithms: ['HS256'] });
    } catch {
      clearRefreshCookie(res);
      return res.status(401).json({
        success: false,
        error: { message: 'Invalid refresh token', code: 'INVALID_REFRESH_TOKEN' },
      });
    }

    // Look up by hash — tokens are stored hashed, never in clear.
    const tokenHash = hashToken(refreshToken);
    const tokenRows = await db
      .select()
      .from(refreshTokensTable)
      .where(eq(refreshTokensTable.token, tokenHash))
      .limit(1);

    if (!tokenRows.length) {
      clearRefreshCookie(res);
      return res.status(401).json({
        success: false,
        error: { message: 'Invalid refresh token', code: 'INVALID_REFRESH_TOKEN' },
      });
    }

    const tokenRecord = tokenRows[0];

    // Check expiry
    if (new Date(tokenRecord.expiresAt) < new Date()) {
      // Clean up expired token
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.id, tokenRecord.id));

      clearRefreshCookie(res);
      return res.status(401).json({
        success: false,
        error: { message: 'Refresh token has expired', code: 'REFRESH_TOKEN_EXPIRED' },
      });
    }

    // Fetch user and verify active
    const userRows = await db
      .select()
      .from(usersTable)
      .where(
        and(
          eq(usersTable.id, tokenRecord.userId),
          eq(usersTable.isActive, true),
        ),
      )
      .limit(1);

    if (!userRows.length) {
      // Drop the stale token for the missing/inactive user.
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.id, tokenRecord.id));

      clearRefreshCookie(res);
      return res.status(401).json({
        success: false,
        error: { message: 'User not found or inactive', code: 'USER_NOT_FOUND' },
      });
    }

    const user = userRows[0];

    // Generate new tokens
    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);

    // Rotate: delete old, insert new (hashed)
    await db
      .delete(refreshTokensTable)
      .where(eq(refreshTokensTable.id, tokenRecord.id));

    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: hashToken(newRefreshToken),
      expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

    setRefreshCookie(res, newRefreshToken);

    return res.json({
      success: true,
      data: {
        tokens: {
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        },
      },
      message: 'Token refreshed successfully',
    });
  } catch (error) {
    log.error('Token refresh error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Token refresh failed', code: 'TOKEN_REFRESH_FAILED' },
    });
  }
};

// ─── Auth: Logout ───────────────────────────────────────────────────────────

const logout = async (req, res) => {
  try {
    const refreshToken = (req.cookies && req.cookies[REFRESH_COOKIE_NAME]) || req.body.refreshToken;

    if (refreshToken) {
      // Tokens are stored hashed, so delete by hash.
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.token, hashToken(refreshToken)));
    }

    // If authenticated, also invalidate all refresh tokens for the user
    if (req.user && req.user.id) {
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.userId, req.user.id));
    }

    clearRefreshCookie(res);
    return res.json({ success: true, data: null, message: 'Logged out successfully' });
  } catch (error) {
    log.error('Logout error', { error: error.message });
    // Always clear the cookie and return success so the client can clear tokens
    clearRefreshCookie(res);
    return res.json({ success: true, data: null, message: 'Logged out successfully' });
  }
};

// ─── Profile: Get ───────────────────────────────────────────────────────────

const getProfile = async (req, res) => {
  try {
    const rows = await db
      .select(userPublicFields)
      .from(usersTable)
      .where(eq(usersTable.id, req.user.id))
      .limit(1);

    if (!rows.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    return res.json({
      success: true,
      data: sanitizeUser(rows[0]),
      message: 'Profile retrieved successfully',
    });
  } catch (error) {
    log.error('Get profile error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to retrieve profile', code: 'PROFILE_RETRIEVAL_FAILED' },
    });
  }
};

// ─── Profile: Update ────────────────────────────────────────────────────────

const updateProfile = async (req, res) => {
  try {
    const { firstName, lastName, email } = req.body;
    const updates = {};

    if (firstName !== undefined) {updates.firstName = firstName.trim();}
    if (lastName !== undefined) {updates.lastName = lastName.trim();}
    if (email !== undefined) {updates.email = email.toLowerCase().trim();}

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        error: { message: 'No fields to update', code: 'NO_FIELDS_TO_UPDATE' },
      });
    }

    // Email uniqueness check (if changing)
    if (updates.email && updates.email !== req.user.email) {
      const conflict = await db
        .select({ id: usersTable.id })
        .from(usersTable)
        .where(
          and(
            eq(usersTable.email, updates.email),
            ne(usersTable.id, req.user.id),
          ),
        )
        .limit(1);

      if (conflict.length > 0) {
        return res.status(409).json({
          success: false,
          error: { message: 'Email is already taken', code: 'EMAIL_ALREADY_TAKEN' },
        });
      }
    }

    updates.updatedAt = new Date();

    const updated = await db
      .update(usersTable)
      .set(updates)
      .where(eq(usersTable.id, req.user.id))
      .returning(userPublicFields);

    if (!updated.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    return res.json({
      success: true,
      data: sanitizeUser(updated[0]),
      message: 'Profile updated successfully',
    });
  } catch (error) {
    log.error('Update profile error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to update profile', code: 'PROFILE_UPDATE_FAILED' },
    });
  }
};

// ─── Profile: Change Password ───────────────────────────────────────────────

const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        error: { message: 'Current password and new password are required', code: 'MISSING_PASSWORD_FIELDS' },
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        error: { message: 'New password must be at least 8 characters', code: 'WEAK_PASSWORD' },
      });
    }

    // Fetch user with passwordHash
    const rows = await db
      .select({ id: usersTable.id, passwordHash: usersTable.passwordHash, tokenVersion: usersTable.tokenVersion })
      .from(usersTable)
      .where(eq(usersTable.id, req.user.id))
      .limit(1);

    if (!rows.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    const user = rows[0];

    // Verify current password
    const isMatch = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        error: { message: 'Current password is incorrect', code: 'INVALID_CURRENT_PASSWORD' },
      });
    }

    // Hash new password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS, 10) || 12;
    const newHash = await bcrypt.hash(newPassword, saltRounds);

    // Update password + increment tokenVersion (invalidates all existing refresh tokens)
    await db
      .update(usersTable)
      .set({
        passwordHash: newHash,
        tokenVersion: (user.tokenVersion || 0) + 1,
        updatedAt: new Date(),
      })
      .where(eq(usersTable.id, user.id));

    // Delete all refresh tokens for this user (force re-login on other devices)
    await db
      .delete(refreshTokensTable)
      .where(eq(refreshTokensTable.userId, user.id));

    return res.json({
      success: true,
      data: null,
      message: 'Password changed successfully — all other sessions have been invalidated',
    });
  } catch (error) {
    log.error('Change password error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to change password', code: 'PASSWORD_CHANGE_FAILED' },
    });
  }
};

// ─── Admin: Get All Users (paginated) ───────────────────────────────────────

const getAllUsers = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;

    // Count total
    const [{ count }] = await db
      .select({ count: sql`count(*)::int` })
      .from(usersTable);

    // Fetch page
    const users = await db
      .select(userPublicFields)
      .from(usersTable)
      .orderBy(desc(usersTable.createdAt))
      .limit(limit)
      .offset(offset);

    return res.json({
      success: true,
      data: {
        users: users.map((user) => sanitizeUser(user)),
        pagination: {
          total: count,
          page,
          limit,
          totalPages: Math.ceil(count / limit),
        },
      },
      message: 'Users retrieved successfully',
    });
  } catch (error) {
    log.error('Get all users error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to retrieve users', code: 'GET_USERS_FAILED' },
    });
  }
};

// ─── Admin: Get User By ID ──────────────────────────────────────────────────

const getUserById = async (req, res) => {
  try {
    const { id } = req.params;

    const rows = await db
      .select(userPublicFields)
      .from(usersTable)
      .where(eq(usersTable.id, id))
      .limit(1);

    if (!rows.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    return res.json({
      success: true,
      data: sanitizeUser(rows[0]),
      message: 'User retrieved successfully',
    });
  } catch (error) {
    log.error('Get user by ID error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to retrieve user', code: 'GET_USER_FAILED' },
    });
  }
};

// ─── Admin: Update User ─────────────────────────────────────────────────────

const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      firstName, lastName, email, phone, role, isActive,
    } = req.body;

    const updates = {};
    if (firstName !== undefined) {updates.firstName = firstName.trim();}
    if (lastName !== undefined) {updates.lastName = lastName.trim();}
    if (email !== undefined) {updates.email = email.toLowerCase().trim();}
    if (phone !== undefined) {updates.phone = phone ? phone.trim() : null;}
    if (role !== undefined) {updates.role = role;}
    if (isActive !== undefined) {updates.isActive = isActive;}

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        error: { message: 'No fields to update', code: 'NO_FIELDS_TO_UPDATE' },
      });
    }

    // Email uniqueness check
    if (updates.email) {
      const conflict = await db
        .select({ id: usersTable.id })
        .from(usersTable)
        .where(
          and(
            eq(usersTable.email, updates.email),
            ne(usersTable.id, id),
          ),
        )
        .limit(1);

      if (conflict.length > 0) {
        return res.status(409).json({
          success: false,
          error: { message: 'Email is already taken', code: 'EMAIL_ALREADY_TAKEN' },
        });
      }
    }

    updates.updatedAt = new Date();

    const updated = await db
      .update(usersTable)
      .set(updates)
      .where(eq(usersTable.id, id))
      .returning(userPublicFields);

    if (!updated.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    return res.json({
      success: true,
      data: sanitizeUser(updated[0]),
      message: 'User updated successfully',
    });
  } catch (error) {
    log.error('Update user error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to update user', code: 'UPDATE_USER_FAILED' },
    });
  }
};

// ─── Admin: Delete User (soft delete) ───────────────────────────────────────

const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;

    // Prevent self-deletion
    if (id === req.user.id) {
      return res.status(400).json({
        success: false,
        error: { message: 'Cannot deactivate your own account', code: 'CANNOT_DELETE_SELF' },
      });
    }

    // Soft delete: set isActive = false
    const updated = await db
      .update(usersTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(usersTable.id, id))
      .returning({ id: usersTable.id });

    if (!updated.length) {
      return res.status(404).json({
        success: false,
        error: { message: 'User not found', code: 'USER_NOT_FOUND' },
      });
    }

    // Delete all refresh tokens for the deactivated user
    await db
      .delete(refreshTokensTable)
      .where(eq(refreshTokensTable.userId, id));

    return res.json({
      success: true,
      data: null,
      message: 'User deactivated successfully',
    });
  } catch (error) {
    log.error('Delete user error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to deactivate user', code: 'DELETE_USER_FAILED' },
    });
  }
};

// ─── Exports ────────────────────────────────────────────────────────────────

module.exports = {
  register,
  login,
  refreshAccessToken,
  logout,
  getProfile,
  updateProfile,
  changePassword,
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser,
};
