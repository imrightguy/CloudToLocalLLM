const { randomUUID } = require('crypto');
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

    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
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

    const [user] = rows;
    req.user = user;
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
  if (!req.user) {return res.status(401).json({ success: false, error: { message: 'Not authenticated', code: 'NOT_AUTHENTICATED' } });}
  if (!roles.includes(req.user.role)) {return res.status(403).json({ success: false, error: { message: 'Insufficient permissions', code: 'FORBIDDEN' } });}
  next();
};

// ─── Company access guard (IDOR protection) ──────────────────────────────────
// This deployment serves a single company. The authorized company id is pinned
// server-side so an authenticated user cannot pass an arbitrary :companyId in
// the URL to read or mutate another tenant's data. If/when users gain a
// per-user companyId, req.user.companyId takes precedence automatically.
const AUTHORIZED_COMPANY_ID = process.env.APP_COMPANY_ID || '388be569-9d9d-46e2-b548-7bf0167cb11b';

const requireCompanyAccess = (req, res, next) => {
  const allowed = req.user?.companyId || AUTHORIZED_COMPANY_ID;
  if (!req.params.companyId || req.params.companyId !== allowed) {
    return res.status(403).json({
      success: false,
      error: { message: 'Accès interdit à cette entreprise', code: 'COMPANY_ACCESS_FORBIDDEN' },
    });
  }
  next();
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
      // Project the same safe columns as authenticateToken — never load
      // passwordHash into req.user.
      const rows = await db.select({
        id: usersTable.id,
        email: usersTable.email,
        firstName: usersTable.firstName,
        lastName: usersTable.lastName,
        role: usersTable.role,
        isActive: usersTable.isActive,
      }).from(usersTable).where(eq(usersTable.id, decoded.userId)).limit(1);
      const [activeUser] = rows;
      if (activeUser && activeUser.isActive) { req.user = activeUser; req.token = token; }
    }
  } catch { /* continue without user */ }
  next();
};

const generateAccessToken = (user) => jwt.sign(
  { userId: user.id, email: user.email, role: user.role },
  process.env.JWT_SECRET,
  { expiresIn: process.env.JWT_EXPIRES_IN || '24h', algorithm: 'HS256' },
);

const generateRefreshToken = (user) => jwt.sign(
  {
    userId: user.id,
    tokenVersion: user.tokenVersion || 1,
    jti: randomUUID(),
  },
  process.env.JWT_REFRESH_SECRET,
  { expiresIn: '7d', algorithm: 'HS256' },
);

module.exports = {
  authenticateToken, authorizeRole, requireCompanyAccess, optionalAuth, generateAccessToken, generateRefreshToken,
};
