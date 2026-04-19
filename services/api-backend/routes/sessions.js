import express from 'express';
import { z } from 'zod';
const router = express.Router();
import db from '../database/db-pool.js';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import logger from '../logger.js';

const updateSessionTokensSchema = {
  body: z.object({
    sessionToken: z.string().min(1, 'sessionToken is required'),
    accessToken: z.string().optional(),
    idToken: z.string().optional(),
    refreshToken: z.string().optional(),
  }),
};

const tokenParamSchema = {
  params: z.object({
    token: z.string().min(1, 'token is required'),
  }),
};

/**
 * POST /auth/sessions
 * Legacy endpoint - now deprecated.
 * Sessions are now automatically synchronized via authenticateJWT middleware.
 */
router.post('/', async (req, res) => {
  res.status(410).json({
    error: 'Gone',
    message:
      'This manual session registration endpoint is deprecated. Sessions are now handled automatically via JWT middleware.',
  });
});

/**
 * GET /auth/sessions/current
 * Get current session for the authenticated user
 */
router.get('/current', authenticateJWT, async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // The syncSession middleware already ensured the session exists
    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at,
              s.jwt_access_token, s.jwt_id_token, s.refresh_token,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.jwt_id, u.email, u.name, u.nickname, u.picture
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE u.jwt_id = $1 AND s.is_active = true AND s.expires_at > NOW()
       ORDER BY s.last_activity DESC LIMIT 1`,
      [req.user.sub],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const session = result.rows[0];

    res.json({
      session: {
        id: session.id,
        token: session.session_token,
        expiresAt: session.expires_at,
        jwtAccessToken: session.jwt_access_token,
        jwtIdToken: session.jwt_id_token,
        refreshToken: session.refresh_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.jwt_id,
        email: session.email,
        name: session.name,
        nickname: session.nickname,
        picture: session.picture,
      },
    });
  } catch (error) {
    logger.error('Error getting current session:', error);
    res.status(500).json({ error: 'Failed to get current session' });
  }
});

/**
 * GET /auth/sessions/validate/:token
 * Validate a session token and return session data
 */
router.get('/validate/:token', validateSchema(tokenParamSchema), authenticateJWT, async (req, res) => {
  try {
    const { token } = req.params;

    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at,
              s.jwt_access_token, s.jwt_id_token, s.refresh_token,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.jwt_id, u.email, u.name, u.nickname, u.picture
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE s.session_token = $1 AND s.is_active = true AND s.expires_at > NOW()`,
      [token],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found or expired' });
    }

    const session = result.rows[0];

    // Update last activity
    await db.query(
      'UPDATE user_sessions SET last_activity = NOW() WHERE id = $1',
      [session.id],
    );

    res.json({
      session: {
        id: session.id,
        token: session.session_token,
        expiresAt: session.expires_at,
        jwtAccessToken: session.jwt_access_token,
        jwtIdToken: session.jwt_id_token,
        refreshToken: session.refresh_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.jwt_id,
        email: session.email,
        name: session.name,
        nickname: session.nickname,
        picture: session.picture,
      },
    });
  } catch (error) {
    logger.error('Error validating session:', error);
    res.status(500).json({ error: 'Failed to validate session' });
  }
});

/**
 * PUT /auth/sessions/tokens
 * Update tokens for the current session
 */
router.put('/tokens', validateSchema(updateSessionTokensSchema), authenticateJWT, async (req, res) => {
  try {
    const { sessionToken, accessToken, idToken, refreshToken } = req.body;

    const result = await db.query(
      `UPDATE user_sessions 
       SET jwt_access_token = $1, 
           jwt_id_token = $2, 
           refresh_token = $3,
           last_activity = NOW()
       WHERE session_token = $4 AND is_active = true
       RETURNING id`,
      [accessToken, idToken, refreshToken, sessionToken],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found or inactive' });
    }

    res.json({ message: 'Tokens updated successfully' });
  } catch (error) {
    logger.error('Error updating session tokens:', error);
    res.status(500).json({ error: 'Failed to update session tokens' });
  }
});

/**
 * DELETE /auth/sessions/:token
 * Invalidate a session
 */
router.delete('/:token', validateSchema(tokenParamSchema), authenticateJWT, async (req, res) => {
  try {
    const { token } = req.params;

    const result = await db.query(
      'UPDATE user_sessions SET is_active = false WHERE session_token = $1',
      [token],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(204).send();
  } catch (error) {
    logger.error('Error invalidating session:', error);
    res.status(500).json({ error: 'Failed to invalidate session' });
  }
});

/**
 * POST /auth/sessions/cleanup
 * Clean up expired sessions
 */
router.post('/cleanup', authenticateJWT, async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM user_sessions WHERE expires_at < NOW() OR is_active = false',
    );

    res.json({ deleted: result.rowCount });
  } catch (error) {
    logger.error('Error cleaning up sessions:', error);
    res.status(500).json({ error: 'Failed to cleanup sessions' });
  }
});

export default router;
