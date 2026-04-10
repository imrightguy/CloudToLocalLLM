const jwt = require('jsonwebtoken');
const { eq } = require('drizzle-orm');
const { db } = require('../database/connection');
const { usersTable } = require('../database/schema');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, error: { message: 'Access token required', code: 'ACCESS_TOKEN_REQUIRED' } });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const rows = await db.select({
      id: usersTable.id,
      email: usersTable.email,
      firstName: usersTable.firstName,
      lastName: usersTable.lastName,
      role: usersTable.role,
      isActive: usersTable.isActive,
    }).from(usersTable).where(eq(usersTable.id, decoded.userId)).limit(1);

    if (!rows.length || !rows[0].isActive) {
      return res.status(401).json({ success: false, error: { message: 'User not found or inactive', code: 'USER_NOT_FOUND' } });
    }

    req.user = rows[0];
    req.token = token;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, error: { message: 'Token expired', code: 'TOKEN_EXPIRED' } });
    }
    return res.status(401).json({ success: false, error: { message: 'Invalid token', code: 'INVALID_TOKEN' } });
  }
};

const authorizeRole = (roles) => (req, res, next) => {
  if (!req.user) return res.status(401).json({ success: false, error: { message: 'Not authenticated', code: 'NOT_AUTHENTICATED' } });
  if (!roles.includes(req.user.role)) return res.status(403).json({ success: false, error: { message: 'Insufficient permissions', code: 'FORBIDDEN' } });
  next();
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const rows = await db.select().from(usersTable).where(eq(usersTable.id, decoded.userId)).limit(1);
      if (rows.length && rows[0].isActive) { req.user = rows[0]; req.token = token; }
    }
  } catch { /* continue without user */ }
  next();
};

const generateAccessToken = (user) => jwt.sign(
  { userId: user.id, email: user.email, role: user.role },
  process.env.JWT_SECRET,
  { expiresIn: process.env.JWT_EXPIRES_IN || '24h' },
);

const generateRefreshToken = (user) => jwt.sign(
  { userId: user.id, tokenVersion: user.tokenVersion || 1 },
  process.env.JWT_REFRESH_SECRET,
  { expiresIn: '7d' },
);

module.exports = {
  authenticateToken, authorizeRole, optionalAuth, generateAccessToken, generateRefreshToken,
};
