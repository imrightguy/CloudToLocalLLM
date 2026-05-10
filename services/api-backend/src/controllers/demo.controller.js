const bcrypt = require('bcryptjs');
const { eq } = require('drizzle-orm');
const { db } = require('../database/connection');
const { usersTable, refreshTokensTable } = require('../database/schema');
const { generateAccessToken, generateRefreshToken } = require('../auth/jwt.middleware');
const { isDemoMode, getDemoModeConfig } = require('../config/demo-mode');
const { child } = require('../utils/logger');

const log = child({ controller: 'demo' });

const COMPANY_NAME = process.env.APP_COMPANY_NAME || 'ImmoGestion';

const DEMO_USER_EMAIL = () => getDemoModeConfig().demoUserEmail;
const DEMO_USER_PASSWORD = () => getDemoModeConfig().demoUserPassword;

const sanitizeUser = (user) => {
  if (!user) {return null;}
  const { passwordHash: _ph, ...safe } = user;
  return { ...safe, company: COMPANY_NAME };
};

const demoLogin = async (req, res) => {
  if (!isDemoMode()) {
    return res.status(403).json({
      success: false,
      error: { message: 'Demo mode is not enabled', code: 'DEMO_MODE_DISABLED' },
    });
  }

  try {
    const config = getDemoModeConfig();
    const email = config.demoUserEmail;
    const password = config.demoUserPassword;

    const rows = await db
      .select()
      .from(usersTable)
      .where(eq(usersTable.email, email))
      .limit(1);

    let user;

    if (!rows.length) {
      log.info('Demo user not found, creating', { email });
      const saltRounds = 12;
      const passwordHash = await bcrypt.hash(password, saltRounds);
      const [created] = await db
        .insert(usersTable)
        .values({
          email,
          passwordHash,
          firstName: 'Demo',
          lastName: 'Utilisateur',
          role: 'admin',
          isActive: true,
          emailVerified: true,
        })
        .returning();
      user = created;
    } else {
      user = rows[0];
      if (!user.isActive) {
        await db
          .update(usersTable)
          .set({ isActive: true, updatedAt: new Date() })
          .where(eq(usersTable.id, user.id));
        user.isActive = true;
      }
    }

    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user);

    await db.insert(refreshTokensTable).values({
      userId: user.id,
      token: refreshToken,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ip: req.ip || null,
      userAgent: req.headers['user-agent'] || null,
    });

    try {
      await db
        .update(usersTable)
        .set({ lastLogin: new Date() })
        .where(eq(usersTable.id, user.id));
    } catch (updateError) {
      log.warn('Failed to update lastLogin for demo user', { error: updateError.message });
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
      message: 'Demo login successful',
    });
  } catch (error) {
    log.error('Demo login error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Demo login failed', code: 'DEMO_LOGIN_FAILED' },
    });
  }
};

const getDemoStatus = async (_req, res) => {
  const config = getDemoModeConfig();
  return res.json({
    success: true,
    data: {
      demoMode: isDemoMode(),
      demoUserEmail: isDemoMode() ? config.demoUserEmail : null,
      writeGuardEnabled: isDemoMode(),
    },
  });
};

module.exports = { demoLogin, getDemoStatus };
