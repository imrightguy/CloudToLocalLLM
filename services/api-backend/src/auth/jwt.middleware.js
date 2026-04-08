const jwt = require('jsonwebtoken');
const { db, connect } = require('../database/connection');
const { schema } = require('../database/schema');

/**
 * JWT Authentication Middleware
 * Validates JWT tokens and attaches user to request object
 */
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Access token required',
          code: 'ACCESS_TOKEN_REQUIRED'
        }
      });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Get user from database
    const userQuery = await db
      .select({
        id: schema.users.id,
        email: schema.users.email,
        firstName: schema.users.firstName,
        lastName: schema.users.lastName,
        role: schema.users.role,
        isActive: schema.users.isActive,
        createdAt: schema.users.createdAt,
        updatedAt: schema.users.updatedAt
      })
      .from(schema.users)
      .where(eq(schema.users.id, decoded.userId))
      .where(eq(schema.users.isActive, true))
      .limit(1);

    if (!userQuery.length) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'User not found or inactive',
          code: 'USER_NOT_FOUND'
        }
      });
    }

    const user = userQuery[0];
    
    // Add user to request object
    req.user = user;
    req.token = token;
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid token',
          code: 'INVALID_TOKEN'
        }
      });
    }

    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Token expired',
          code: 'TOKEN_EXPIRED'
        }
      });
    }

    console.error('Authentication error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Authentication failed',
        code: 'AUTHENTICATION_FAILED'
      }
    });
  }
};

/**
 * Role-based Authorization Middleware
 * Checks if user has required role
 */
const authorizeRole = (roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED'
        }
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: {
          message: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS'
        }
      });
    }

    next();
  };
};

/**
 * Optional Authentication Middleware
 * Allows request to proceed even without valid token
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      const userQuery = await db
        .select({
          id: schema.users.id,
          email: schema.users.email,
          firstName: schema.users.firstName,
          lastName: schema.users.lastName,
          role: schema.users.role,
          isActive: schema.users.isActive,
          createdAt: schema.users.createdAt,
          updatedAt: schema.users.updatedAt
        })
        .from(schema.users)
        .where(eq(schema.users.id, decoded.userId))
        .where(eq(schema.users.isActive, true))
        .limit(1);

      if (userQuery.length) {
        req.user = userQuery[0];
        req.token = token;
      }
    }

    next();
  } catch (error) {
    // If optional auth fails, just continue without user data
    console.warn('Optional auth failed:', error.message);
    next();
  }
};

/**
 * Rate Limit by User Middleware
 * Prevents abuse by limiting API calls per user
 */
const rateLimitByUser = async (req, res, next) => {
  try {
    if (!req.user) {
      return next(); // Skip rate limiting for unauthenticated requests
    }

    const now = Date.now();
    const windowMs = 15 * 60 * 1000; // 15 minutes
    const maxRequests = 100; // 100 requests per window

    // Get current rate limit count
    const rateLimitQuery = await db
      .select()
      .from(schema.rateLimits)
      .where(
        and(
          eq(schema.rateLimits.userId, req.user.id),
          gte(schema.rateLimits.timestamp, now - windowMs)
        )
      );

    // If exceeded, return error
    if (rateLimitQuery.length >= maxRequests) {
      return res.status(429).json({
        success: false,
        error: {
          message: 'Too many requests. Please try again later.',
          code: 'RATE_LIMIT_EXCEEDED'
        }
      });
    }

    // Increment rate limit
    await db.insert(schema.rateLimits).values({
      userId: req.user.id,
      timestamp: now
    });

    next();
  } catch (error) {
    console.error('Rate limiting error:', error);
    next(); // Continue if rate limiting fails
  }
};

/**
 * Refresh Token Middleware
 * Handles token refresh logic
 */
const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Refresh token required',
          code: 'REFRESH_TOKEN_REQUIRED'
        }
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(token, process.env.JWT_REFRESH_SECRET);
    
    // Get user from database
    const userQuery = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, decoded.userId))
      .where(eq(schema.users.isActive, true))
      .limit(1);

    if (!userQuery.length) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid refresh token',
          code: 'INVALID_REFRESH_TOKEN'
        }
      });
    }

    // Generate new access token
    const newAccessToken = generateAccessToken(userQuery[0]);
    
    res.json({
      success: true,
      data: {
        accessToken: newAccessToken,
        tokenType: 'Bearer',
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
      }
    });
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid refresh token',
          code: 'INVALID_REFRESH_TOKEN'
        }
      });
    }

    console.error('Refresh token error:', error);
    return res.status(500).json({
      success: false,
      error: {
        message: 'Token refresh failed',
        code: 'TOKEN_REFRESH_FAILED'
      }
    });
  }
};

/**
 * Generate JWT Access Token
 */
const generateAccessToken = (user) => {
  return jwt.sign(
    { 
      userId: user.id,
      email: user.email,
      role: user.role 
    },
    process.env.JWT_SECRET,
    { 
      expiresIn: process.env.JWT_EXPIRES_IN || '24h' 
    }
  );
};

/**
 * Generate JWT Refresh Token
 */
const generateRefreshToken = (user) => {
  return jwt.sign(
    { 
      userId: user.id,
      tokenVersion: user.tokenVersion || 1 
    },
    process.env.JWT_REFRESH_SECRET,
    { 
      expiresIn: '7d' 
    }
  );
};

/**
 * Logout User
 * Invalidates user's refresh token
 */
const logoutUser = async (userId) => {
  try {
    // Increment user's token version to invalidate refresh tokens
    await db
      .update(schema.users)
      .set({
        tokenVersion: sql`${schema.users.tokenVersion} + 1`,
        updatedAt: new Date()
      })
      .where(eq(schema.users.id, userId));
    
    return true;
  } catch (error) {
    console.error('Logout error:', error);
    return false;
  }
};

module.exports = {
  authenticateToken,
  authorizeRole,
  optionalAuth,
  rateLimitByUser,
  refreshToken,
  generateAccessToken,
  generateRefreshToken,
  logoutUser
};