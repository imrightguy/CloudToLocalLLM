const bcrypt = require('bcryptjs');
const { db } = require('../database/connection');
const { usersTable, refreshTokensTable } = require('../database/schema');
const { generateAccessToken, generateRefreshToken } = require('../auth/jwt.middleware');
const { eq, and, ne, sql, desc } = require('drizzle-orm');

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Strip passwordHash from a user row */
const sanitizeUser = user => {
  if (!user) return null;
  const { passwordHash, ...safe } = user;
  return safe;
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
    const { email, password, firstName, lastName, phone } = req.body;

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

    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        error: { message: 'A user with this email already exists', code: 'USER_ALREADY_EXISTS' },
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
      })
      .returning(userPublicFields);

    if (!created.length) {
      return res.status(500).json({
        success: false,
        error: { message: 'User creation failed', code: 'USER_CREATION_FAILED' },
      });
    }

    const user = created[0];

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Persist refresh token
    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

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
    console.error('Registration error:', error);
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

    // Persist refresh token
    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

    // Update lastLogin
    await db
      .update(usersTable)
      .set({ lastLogin: new Date() })
      .where(eq(usersTable.id, user.id));

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
    console.error('Login error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Login failed', code: 'LOGIN_FAILED' },
    });
  }
};

// ─── Auth: Refresh Access Token ─────────────────────────────────────────────

const refreshAccessToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: { message: 'Refresh token is required', code: 'REFRESH_TOKEN_REQUIRED' },
      });
    }

    // Look up refresh token in DB
    const tokenRows = await db
      .select()
      .from(refreshTokensTable)
      .where(eq(refreshTokensTable.token, refreshToken))
      .limit(1);

    if (!tokenRows.length) {
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

      return res.status(401).json({
        success: false,
        error: { message: 'Refresh token has expired', code: 'REFRESH_TOKEN_EXPIRED' },
      });
    }

    // Fetch user and verify active + tokenVersion
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
      return res.status(401).json({
        success: false,
        error: { message: 'User not found or inactive', code: 'USER_NOT_FOUND' },
      });
    }

    const user = userRows[0];

    // Verify tokenVersion matches (detects password resets / forced logouts)
    if (user.tokenVersion !== tokenRecord.tokenVersion) {
      // Token version mismatch — delete this stale token
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.id, tokenRecord.id));

      return res.status(401).json({
        success: false,
        error: { message: 'Session invalidated — please log in again', code: 'TOKEN_VERSION_MISMATCH' },
      });
    }

    // Generate new tokens
    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);

    // Rotate: delete old, insert new
    await db
      .delete(refreshTokensTable)
      .where(eq(refreshTokensTable.id, tokenRecord.id));

    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: newRefreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

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
    console.error('Token refresh error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Token refresh failed', code: 'TOKEN_REFRESH_FAILED' },
    });
  }
};

// ─── Auth: Logout ───────────────────────────────────────────────────────────

const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.token, refreshToken));
    }

    // If authenticated, also invalidate all refresh tokens for the user
    if (req.user && req.user.id) {
      await db
        .delete(refreshTokensTable)
        .where(eq(refreshTokensTable.userId, req.user.id));
    }

    return res.json({ success: true, data: null, message: 'Logged out successfully' });
  } catch (error) {
    console.error('Logout error:', error);
    // Always return success on logout so the client can clear tokens
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
      data: rows[0],
      message: 'Profile retrieved successfully',
    });
  } catch (error) {
    console.error('Get profile error:', error);
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

    if (firstName !== undefined) updates.firstName = firstName.trim();
    if (lastName !== undefined) updates.lastName = lastName.trim();
    if (email !== undefined) updates.email = email.toLowerCase().trim();

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
      data: updated[0],
      message: 'Profile updated successfully',
    });
  } catch (error) {
    console.error('Update profile error:', error);
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
    console.error('Change password error:', error);
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
        users,
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
    console.error('Get all users error:', error);
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
      data: rows[0],
      message: 'User retrieved successfully',
    });
  } catch (error) {
    console.error('Get user by ID error:', error);
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
    const { firstName, lastName, email, phone, role, isActive } = req.body;

    const updates = {};
    if (firstName !== undefined) updates.firstName = firstName.trim();
    if (lastName !== undefined) updates.lastName = lastName.trim();
    if (email !== undefined) updates.email = email.toLowerCase().trim();
    if (phone !== undefined) updates.phone = phone ? phone.trim() : null;
    if (role !== undefined) updates.role = role;
    if (isActive !== undefined) updates.isActive = isActive;

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
      data: updated[0],
      message: 'User updated successfully',
    });
  } catch (error) {
    console.error('Update user error:', error);
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
    console.error('Delete user error:', error);
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
