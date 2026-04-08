const bcrypt = require('bcryptjs');
const { db, connect } = require('../database/connection');
const { schema } = require('../database/schema');
const { generateAccessToken, generateRefreshToken, logoutUser } = require('../auth/jwt.middleware');
const { errorResponse, successResponse } = require('../utils/apiResponse');

// Drizzle ORM operators for database queries
const { eq, and, or, ilike, ne } = require('drizzle-orm');

/**
 * Authentication Controller
 * Handles user registration, login, logout, and token management
 */

/**
 * Register a new user
 */
const register = async (req, res) => {
  try {
    const { email, password, firstName, lastName, role = 'employee', companyId } = req.body;

    // Validate input
    if (!email || !password || !firstName || !lastName) {
      return res.status(400).json(errorResponse({
        message: 'Missing required fields',
        code: 'MISSING_REQUIRED_FIELDS'
      }));
    }

    // Connect to database
    await connect();

    // Check if user already exists
    const existingUser = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.email, email.toLowerCase()))
      .limit(1);

    if (existingUser.length > 0) {
      return res.status(409).json(errorResponse({
        message: 'User already exists with this email',
        code: 'USER_ALREADY_EXISTS'
      }));
    }

    // Hash password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Create user
    const newUser = await db.insert(schema.users).values({
      email: email.toLowerCase(),
      password: hashedPassword,
      firstName,
      lastName,
      role,
      companyId,
      isActive: true,
      emailVerified: false,
      tokenVersion: 0
    }).returning({
      id: schema.users.id,
      email: schema.users.email,
      firstName: schema.users.firstName,
      lastName: schema.users.lastName,
      role: schema.users.role,
      companyId: schema.users.companyId,
      createdAt: schema.users.createdAt
    });

    if (!newUser.length) {
      throw new Error('User creation failed');
    }

    const user = newUser[0];

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token
    await db.insert(schema.refreshTokens).values({
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      ip: req.ip,
      userAgent: req.headers['user-agent']
    });

    // Send welcome email (placeholder - implement email service)
    await sendWelcomeEmail(user);

    res.status(201).json(successResponse({
      data: {
        user: {
          id: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          role: user.role,
          companyId: user.companyId,
          createdAt: user.createdAt
        },
        tokens: {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h'
        }
      },
      message: 'User registered successfully'
    }));
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json(errorResponse({
      message: 'Registration failed',
      code: 'REGISTRATION_FAILED'
    }));
  }
};

/**
 * User login
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json(errorResponse({
        message: 'Email and password are required',
        code: 'MISSING_CREDENTIALS'
      }));
    }

    // Connect to database
    await connect();

    // Find user
    const userQuery = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.email, email.toLowerCase()))
      .limit(1);

    if (!userQuery.length) {
      return res.status(401).json(errorResponse({
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      }));
    }

    const user = userQuery[0];

    // Check if user is active
    if (!user.isActive) {
      return res.status(401).json(errorResponse({
        message: 'Account is inactive',
        code: 'ACCOUNT_INACTIVE'
      }));
    }

    // Check password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      // Log failed login attempt
      await logFailedLogin(user.id, req.ip);
      return res.status(401).json(errorResponse({
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      }));
    }

    // Generate tokens
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    // Store refresh token
    await db.insert(schema.refreshTokens).values({
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      ip: req.ip,
      userAgent: req.headers['user-agent']
    });

    // Update last login
    await db
      .update(schema.users)
      .set({ lastLogin: new Date() })
      .where(eq(schema.users.id, user.id));

    res.json(successResponse({
      data: {
        user: {
          id: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          role: user.role,
          companyId: user.companyId,
          createdAt: user.createdAt,
          lastLogin: user.lastLogin
        },
        tokens: {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h'
        }
      },
      message: 'Login successful'
    }));
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json(errorResponse({
      message: 'Login failed',
      code: 'LOGIN_FAILED'
    }));
  }
};

/**
 * User logout
 */
const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json(errorResponse({
        message: 'Refresh token is required',
        code: 'REFRESH_TOKEN_REQUIRED'
      }));
    }

    // Delete refresh token
    await db
      .delete(schema.refreshTokens)
      .where(eq(schema.refreshTokens.token, refreshToken));

    // Invalidate all refresh tokens for the user
    if (req.user) {
      await logoutUser(req.user.id);
    }

    res.json(successResponse({
      message: 'Logout successful'
    }));
  } catch (error) {
    console.error('Logout error:', error);
    // Even if logout fails, still return success to client
    res.json(successResponse({
      message: 'Logout successful'
    }));
  }
};

/**
 * Refresh access token
 */
const refreshAccessToken = async (req, res) => {
  try {
    const refreshToken = req.body.refreshToken;

    if (!refreshToken) {
      return res.status(400).json(errorResponse({
        message: 'Refresh token is required',
        code: 'REFRESH_TOKEN_REQUIRED'
      }));
    }

    // Find refresh token
    const tokenQuery = await db
      .select()
      .from(schema.refreshTokens)
      .where(eq(schema.refreshTokens.token, refreshToken))
      .limit(1);

    if (!tokenQuery.length) {
      return res.status(401).json(errorResponse({
        message: 'Invalid refresh token',
        code: 'INVALID_REFRESH_TOKEN'
      }));
    }

    const token = tokenQuery[0];

    // Check if token is expired
    if (new Date(token.expiresAt) < new Date()) {
      await db
        .delete(schema.refreshTokens)
        .where(eq(schema.refreshTokens.token, refreshToken));
      return res.status(401).json(errorResponse({
        message: 'Refresh token expired',
        code: 'REFRESH_TOKEN_EXPIRED'
      }));
    }

    // Get user
    const userQuery = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, token.userId))
      .where(eq(schema.users.isActive, true))
      .limit(1);

    if (!userQuery.length) {
      return res.status(401).json(errorResponse({
        message: 'User not found or inactive',
        code: 'USER_NOT_FOUND'
      }));
    }

    const user = userQuery[0];

    // Generate new tokens
    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);

    // Update refresh token
    await db
      .update(schema.refreshTokens)
      .set({
        token: newRefreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        ip: req.ip,
        userAgent: req.headers['user-agent']
      })
      .where(eq(schema.refreshTokens.token, refreshToken));

    res.json(successResponse({
      data: {
        tokens: {
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          tokenType: 'Bearer',
          expiresIn: process.env.JWT_EXPIRES_IN || '24h'
        }
      },
      message: 'Token refreshed successfully'
    }));
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json(errorResponse({
      message: 'Token refresh failed',
      code: 'TOKEN_REFRESH_FAILED'
    }));
  }
};

/**
 * Get current user profile
 */
const getProfile = async (req, res) => {
  try {
    const user = req.user;

    // Get additional user data
    const userProfile = await db
      .select({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        companyId: schema.users.companyId,
        isActive: schema.users.isActive,
        emailVerified: schema.users.emailVerified,
        createdAt: schema.users.createdAt,
        updatedAt: schema.users.updatedAt,
        lastLogin: schema.users.lastLogin
      })
      .from(schema.users)
      .where(eq(schema.users.id, user.id))
      .limit(1);

    if (!userProfile.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    res.json(successResponse({
      data: userProfile[0],
      message: 'Profile retrieved successfully'
    }));
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to retrieve profile',
      code: 'PROFILE_RETRIEVAL_FAILED'
    }));
  }
};

/**
 * Update user profile
 */
const updateProfile = async (req, res) => {
  try {
    const { email, firstName, lastName } = req.body;
    const userId = req.user.id;

    const updates = {};
    if (email) updates.email = email.toLowerCase();
    if (firstName) updates.firstName = firstName;
    if (lastName) updates.lastName = lastName;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json(errorResponse({
        message: 'No fields to update',
        code: 'NO_FIELDS_TO_UPDATE'
      }));
    }

    // Check if email is already taken
    if (email && email !== req.user.email) {
      const existingUser = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.email, email.toLowerCase()))
        .where(ne(schema.users.id, userId))
        .limit(1);

      if (existingUser.length > 0) {
        return res.status(409).json(errorResponse({
          message: 'Email already taken',
          code: 'EMAIL_ALREADY_TAKEN'
        }));
      }
    }

    // Update user
    const updatedUser = await db
      .update(schema.users)
      .set({
        ...updates,
        updatedAt: new Date()
      })
      .where(eq(schema.users.id, userId))
      .returning({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        companyId: schema.users.companyId,
        isActive: schema.users.isActive,
        updatedAt: schema.users.updatedAt
      });

    if (!updatedUser.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    res.json(successResponse({
      data: updatedUser[0],
      message: 'Profile updated successfully'
    }));
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to update profile',
      code: 'PROFILE_UPDATE_FAILED'
    }));
  }
};

/**
 * Change password
 */
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    if (!currentPassword || !newPassword) {
      return res.status(400).json(errorResponse({
        message: 'Current password and new password are required',
        code: 'MISSING_PASSWORD_FIELDS'
      }));
    }

    // Get user
    const userQuery = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, userId))
      .limit(1);

    if (!userQuery.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    const user = userQuery[0];

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isCurrentPasswordValid) {
      return res.status(400).json(errorResponse({
        message: 'Current password is incorrect',
        code: 'INVALID_CURRENT_PASSWORD'
      }));
    }

    // Hash new password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
    const hashedNewPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await db
      .update(schema.users)
      .set({
        password: hashedNewPassword,
        updatedAt: new Date()
      })
      .where(eq(schema.users.id, userId));

    // Log password change
    await logPasswordChange(userId, req.ip);

    res.json(successResponse({
      message: 'Password changed successfully'
    }));
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to change password',
      code: 'PASSWORD_CHANGE_FAILED'
    }));
  }
};

// Helper functions
const sendWelcomeEmail = async (user) => {
  // Placeholder for email service implementation
  console.log('Welcome email to:', user.email);
  console.log('User:', {
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email
  });
};

const logFailedLogin = async (userId, ip) => {
  try {
    await db.insert(schema.loginAttempts).values({
      userId,
      ip,
      success: false,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Failed to log login attempt:', error);
  }
};

const logPasswordChange = async (userId, ip) => {
  try {
    await db.insert(schema.passwordChanges).values({
      userId,
      ip,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Failed to log password change:', error);
  }
};

/**
 * Get all users (admin only)
 */
const getAllUsers = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, role } = req.query;
    const offset = (page - 1) * limit;

    // Build query
    let query = db
      .select({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        companyId: schema.users.companyId,
        isActive: schema.users.isActive,
        createdAt: schema.users.createdAt,
        lastLogin: schema.users.lastLogin
      })
      .from(schema.users);

    // Apply filters
    if (search) {
      const searchTerm = `%${search.toLowerCase()}%`;
      query = query.where(
        or(
          ilike(schema.users.firstName, searchTerm),
          ilike(schema.users.lastName, searchTerm),
          ilike(schema.users.email, searchTerm)
        )
      );
    }

    if (role) {
      query = query.where(eq(schema.users.role, role));
    }

    // Get total count for pagination
    const countQuery = await db.select().from(schema.users);
    const totalCount = countQuery.length;

    // Get paginated results
    const usersQuery = await query
      .orderBy(schema.users.createdAt, 'desc')
      .limit(parseInt(limit))
      .offset(offset);

    const users = usersQuery;

    res.json(successResponse({
      data: {
        users,
        pagination: {
          total: totalCount,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(totalCount / limit)
        }
      },
      message: 'Users retrieved successfully'
    }));
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to retrieve users',
      code: 'GET_USERS_FAILED'
    }));
  }
};

/**
 * Get user by ID (admin only)
 */
const getUserById = async (req, res) => {
  try {
    const { id } = req.params;

    const userQuery = await db
      .select({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        companyId: schema.users.companyId,
        isActive: schema.users.isActive,
        createdAt: schema.users.createdAt,
        updatedAt: schema.users.updatedAt,
        lastLogin: schema.users.lastLogin
      })
      .from(schema.users)
      .where(eq(schema.users.id, id))
      .limit(1);

    if (!userQuery.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    res.json(successResponse({
      data: userQuery[0],
      message: 'User retrieved successfully'
    }));
  } catch (error) {
    console.error('Get user by ID error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to retrieve user',
      code: 'GET_USER_FAILED'
    }));
  }
};

/**
 * Update user (admin only)
 */
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { email, firstName, lastName, role, isActive, companyId } = req.body;

    const updates = {};
    if (email !== undefined) updates.email = email.toLowerCase();
    if (firstName !== undefined) updates.firstName = firstName;
    if (lastName !== undefined) updates.lastName = lastName;
    if (role !== undefined) updates.role = role;
    if (isActive !== undefined) updates.isActive = isActive;
    if (companyId !== undefined) updates.companyId = companyId;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json(errorResponse({
        message: 'No fields to update',
        code: 'NO_FIELDS_TO_UPDATE'
      }));
    }

    // Check if email is already taken
    if (email && email !== req.user.email) {
      const existingUser = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.email, email.toLowerCase()))
        .where(ne(schema.users.id, id))
        .limit(1);

      if (existingUser.length > 0) {
        return res.status(409).json(errorResponse({
          message: 'Email already taken',
          code: 'EMAIL_ALREADY_TAKEN'
        }));
      }
    }

    // Update user
    const updatedUser = await db
      .update(schema.users)
      .set({
        ...updates,
        updatedAt: new Date()
      })
      .where(eq(schema.users.id, id))
      .returning({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        companyId: schema.users.companyId,
        isActive: schema.users.isActive,
        updatedAt: schema.users.updatedAt
      });

    if (!updatedUser.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    res.json(successResponse({
      data: updatedUser[0],
      message: 'User updated successfully'
    }));
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to update user',
      code: 'UPDATE_USER_FAILED'
    }));
  }
};

/**
 * Delete user (admin only)
 */
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;

    // Prevent self-deletion
    if (id === req.user.id) {
      return res.status(400).json(errorResponse({
        message: 'Cannot delete your own account',
        code: 'CANNOT_DELETE_SELF'
      }));
    }

    // Check if user exists
    const userQuery = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, id))
      .limit(1);

    if (!userQuery.length) {
      return res.status(404).json(errorResponse({
        message: 'User not found',
        code: 'USER_NOT_FOUND'
      }));
    }

    // Delete user
    await db
      .delete(schema.users)
      .where(eq(schema.users.id, id));

    res.json(successResponse({
      message: 'User deleted successfully'
    }));
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json(errorResponse({
      message: 'Failed to delete user',
      code: 'DELETE_USER_FAILED'
    }));
  }
};

module.exports = {
  register,
  login,
  logout,
  refreshAccessToken,
  getProfile,
  updateProfile,
  changePassword,
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser
};
