/**
 * @fileoverview Authentication Service for CloudToLocalLLM Tunnel
 * Handles JWT JWT validation, session management, and role-based access control
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import jwksClient from 'jwks-rsa';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigratorPG } from '../database/migrate-pg.js';

/**
 * Authentication service with JWT integration
 * Uses separate authentication database for security isolation
 */
export class AuthService {
  constructor(config) {
    this.config = {
      AUTH0_JWKS_URI:
        process.env.AUTH0_JWKS_URI ||
        'https://${AUTH0_DOMAIN}/.well-known/jwks.json',
      AUTH0_AUDIENCE:
        process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.online',
      SESSION_TIMEOUT: parseInt(process.env.SESSION_TIMEOUT) || 3600000, // 1 hour
      MAX_SESSIONS_PER_USER: parseInt(process.env.MAX_SESSIONS_PER_USER) || 5,
      ...config,
    };

    this.logger = new TunnelLogger('auth-service');
    // Use separate auth database if provided, otherwise fallback to main database
    this.authDbMigrator = config.authDbMigrator || null;
    this.mainDbMigrator = config.dbMigrator || null;

    // Default to Postgres
    if (this.authDbMigrator) {
      this.db = this.authDbMigrator;
    } else if (this.mainDbMigrator) {
      this.db = this.mainDbMigrator;
    } else {
      this.db = new DatabaseMigratorPG();
    }

    this.initialized = false;

    // Initialize JWKS client for Auth0
    this.jwksClient = jwksClient({
      jwksUri: this.config.AUTH0_JWKS_URI,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
  }

  /**
   * Initialize authentication service
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    try {
      // If using separate auth database or main db migrator, it's already initialized in server.js
      if (!this.authDbMigrator && !this.mainDbMigrator) {
        await this.db.initialize();
      }
      this.initialized = true;

      this.logger.info(
        'Authentication service initialized (Auth0 RS256/ES256)',
      );

      // Start session cleanup
      this.startSessionCleanup();
    } catch (error) {
      this.logger.error('Failed to initialize authentication service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Helper to execute queries on Postgres
   * Handles parameter conversion (? -> $n) and standardized return format
   */
  async runQuery(sql, params = [], type = 'all') {
    // Convert ? to $1, $2, etc. (Naive replacement, assumes no ? in strings)
    let paramCount = 0;
    const pgSql = sql.replace(/\?/g, () => {
      paramCount++;
      return `$${paramCount}`;
    });

    // Special handling for INSERT to get lastID
    let finalSql = pgSql;
    if (type === 'run' && sql.trim().toUpperCase().startsWith('INSERT')) {
      finalSql += ' RETURNING id';
    }

    try {
      const result = await this.db.pool.query(finalSql, params);

      if (type === 'run') {
        return {
          lastID: result.rows.length > 0 ? result.rows[0].id : null,
          changes: result.rowCount,
          rows: result.rows,
        };
      } else if (type === 'get') {
        return result.rows[0];
      } else {
        return result.rows;
      }
    } catch (err) {
      // Handle unique constraint violations
      if (err.code === '23505') {
        const wrapper = new Error('UNIQUE constraint failed: ' + err.detail);
        wrapper.code = 'UNIQUE_VIOLATION';
        throw wrapper;
      }
      throw err;
    }
  }

  /**
   * Get signing key from JWKS
   */
  getKey(header, callback) {
    this.jwksClient.getSigningKey(header.kid, (err, key) => {
      if (err) {
        callback(err);
        return;
      }
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    });
  }

  /**
   * Check if a token is valid and active in the database
   * Used for synchronized session validation and revocation support
   */
  async isTokenActive(userId, token) {
    const tokenHash = this.hashToken(token);
    try {
      const session = await this.runQuery(
        'SELECT is_active FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
        'get',
      );

      if (session) {
        return session.is_active === true;
      }

      return false;
    } catch (error) {
      this.logger.error('Failed to check token status', { userId, error: error.message });
      return false;
    }
  }

  /**
   * Synchronize session state from a validated JWT
   */
  async syncSession(tokenPayload, token, req) {
    return this.createOrUpdateSession(tokenPayload, token, req);
  }

  /**
   * Validate JWT token
   */
  async validateToken(token, req = {}, preValidatedPayload = null) {
    try {
      let payload;

      if (preValidatedPayload) {
        this.logger.info('Using pre-validated token payload');
        payload = preValidatedPayload;
      } else {
        const decoded = jwt.decode(token, { complete: true });
        if (!decoded || !decoded.header) {
          throw new Error('Invalid token structure');
        }

        const alg = decoded.header.alg;
        this.logger.info(`Starting token validation (Alg: ${alg})`);

        payload = await new Promise((resolve, reject) => {
          jwt.verify(
            token,
            this.getKey.bind(this),
            { algorithms: ['RS256', 'ES256'] },
            (err, decodedToken) => {
              if (err) {
                reject(err);
              } else {
                if (decodedToken.aud !== this.config.AUTH0_AUDIENCE) {
                  reject(
                    new Error(
                      `Invalid audience: expected ${this.config.AUTH0_AUDIENCE}, got ${decodedToken.aud}`,
                    ),
                  );
                } else {
                  resolve(decodedToken);
                }
              }
            },
          );
        });

        this.logger.info('Token verification successful (Audience verified)');
      }

      const session = await this.createOrUpdateSession(payload, token, req);

      this.logger.info('Token validated successfully', {
        userId: payload.sub,
        sessionId: session.id,
      });

      return {
        valid: true,
        payload: payload,
        session: session,
      };
    } catch (error) {
      this.logger.warn(`Token validation failed: ${error.message}`, {
        error: error.message,
        ip: req.ip,
      });

      await this.logSecurityEvent('token_validation_failure', {
        error: error.message,
        ip: req.ip,
        userAgent: req.headers?.['user-agent'],
      });

      return {
        valid: false,
        error: error.message,
      };
    }
  }

  /**
   * Validate JWT token for WebSocket connections
   */
  async validateTokenForWebSocket(token) {
    try {
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header) {
        throw new Error('Invalid token structure');
      }

      const verified = await new Promise((resolve, reject) => {
        jwt.verify(
          token,
          this.getKey.bind(this),
          { algorithms: ['RS256', 'ES256'] },
          (err, decodedToken) => {
            if (err) {
              reject(err);
            } else {
              resolve(decodedToken);
            }
          },
        );
      });

      this.logger.info('WebSocket token verification successful', {
        userId: verified.sub,
        exp: verified.exp,
      });

      return verified;
    } catch (error) {
      this.logger.warn('WebSocket token validation failed', {
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Resolve internal user ID from Auth0 ID
   */
  async resolveUserId(auth0Id, userInfo = {}) {
    try {
      // 1. Try to find existing user
      const existingUser = await this.runQuery(
        'SELECT id FROM users WHERE jwt_id = ?',
        [auth0Id],
        'get',
      );

      if (existingUser) {
        return existingUser.id;
      }

      // 2. Try to find user by email
      const userEmail = userInfo.email || `${auth0Id}@placeholder.local`;
      const existingByEmail = await this.runQuery(
        'SELECT id FROM users WHERE email = ?',
        [userEmail],
        'get',
      );

      if (existingByEmail) {
        this.logger.info('Found existing user by email, linking jwt_id', {
          userId: existingByEmail.id,
          email: userEmail,
        });

        await this.runQuery(
          `UPDATE users SET 
             jwt_id = ?, 
             name = COALESCE(?, name),
             nickname = COALESCE(?, nickname),
             picture = COALESCE(?, picture),
             email_verified = ?, 
             locale = COALESCE(?, locale),
             updated_at = NOW() 
           WHERE id = ?`,
          [
            auth0Id,
            userInfo.name,
            userInfo.nickname,
            userInfo.picture,
            userInfo.email_verified || false,
            userInfo.locale,
            existingByEmail.id,
          ],
          'run',
        );
        return existingByEmail.id;
      }

      // 3. Create new user
      this.logger.info('Creating new user record for Auth0 ID', { auth0Id });

      const newUser = await this.runQuery(
        `INSERT INTO users (jwt_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW()) RETURNING id`,
        [
          auth0Id,
          userEmail,
          userInfo.name,
          userInfo.nickname,
          userInfo.picture,
          userInfo.email_verified || false,
          userInfo.locale,
        ],
        'run',
      );

      if (newUser && newUser.rows && newUser.rows.length > 0) {
        return newUser.rows[0].id;
      }

      throw new Error('Failed to create user record');
    } catch (error) {
      this.logger.error('Failed to resolve user ID', {
        auth0Id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create or update user session
   */
  async createOrUpdateSession(tokenPayload, token, req) {
    const auth0Id = tokenPayload.sub;
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(tokenPayload.exp * 1000).toISOString();
    const ip = req.ip || req.socket?.remoteAddress;
    const userAgent = req.headers?.['user-agent'];

    try {
      // Resolve the internal User ID
      const userId = await this.resolveUserId(auth0Id, tokenPayload);

      // Check for existing session with same token
      const existingSession = await this.runQuery(
        'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
        'get',
      );

      if (existingSession) {
        await this.runQuery(
          'UPDATE user_sessions SET last_activity = NOW(), expires_at = ? WHERE id = ?',
          [expiresAt, existingSession.id],
          'run',
        );
        return existingSession;
      }

      // Clean up old sessions
      await this.cleanupUserSessions(userId);

      // Create new session
      await this.runQuery(
        'INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent, session_token)' +
         'VALUES (?, ?, ?, ?, ?, ?)',
        [
          userId,
          tokenHash,
          expiresAt,
          ip,
          userAgent,
          this.generateSessionId(),
        ],
        'run',
      );

      const session = await this.runQuery(
        'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
        [userId, tokenHash],
        'get',
      );

      if (!session) {
        throw new Error('Failed to retrieve created session');
      }

      await this.logAuditEvent('session_created', 'authentication', {
        userId,
        sessionId: session.id,
        ip,
      });

      return session;
    } catch (error) {
      if (error.code === 'UNIQUE_VIOLATION') {
        const userId = await this.resolveUserId(auth0Id, tokenPayload);
        const existingSession = await this.runQuery(
          'SELECT * FROM user_sessions WHERE user_id = ? AND jwt_token_hash = ?',
          [userId, tokenHash],
          'get',
        );
        if (existingSession) {
          return existingSession;
        }
      }
      throw error;
    }
  }

  async getSession(sessionId) {
    try {
      const result = await this.runQuery(
        'SELECT * FROM user_sessions' +
         `
         WHERE id = ? AND is_active = true AND expires_at > NOW()`,
        [sessionId],
        'get',
      );
      return result || null;
    } catch {
      return null;
    }
  }

  async invalidateSession(sessionId, reason = 'logout') {
    try {
      const session = await this.runQuery(
        'SELECT user_id FROM user_sessions WHERE id = ?',
        [sessionId],
        'get',
      );

      if (session) {
        await this.runQuery(
          'UPDATE user_sessions SET is_active = false WHERE id = ?',
          [sessionId],
          'run',
        );
        await this.logAuditEvent('session_invalidated', 'authentication', {
          userId: session.user_id,
          sessionId,
          reason,
        });
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }

  async cleanupUserSessions(userId) {
    try {
      const countResult = await this.runQuery(
        'SELECT COUNT(*) as count FROM user_sessions WHERE user_id = ? AND is_active = true',
        [userId],
        'get',
      );

      const activeCount = parseInt(countResult.count);
      if (activeCount >= this.config.MAX_SESSIONS_PER_USER) {
        const sessionsToRemove = activeCount - this.config.MAX_SESSIONS_PER_USER + 1;
        const subQuery = `
          SELECT id FROM user_sessions
          WHERE user_id = ? AND is_active = true
          ORDER BY last_activity ASC
          LIMIT ?
        `;
        await this.runQuery(
          `UPDATE user_sessions SET is_active = false WHERE id IN (${subQuery})`,
          [userId, sessionsToRemove],
          'run',
        );
      }
    } catch (error) {
      this.logger.error('Failed to cleanup user sessions', { userId, error: error.message });
    }
  }

  async checkPermissions(userId, resource, action) {
    const allowedActions = ['connect', 'send_request', 'receive_response'];
    if (allowedActions.includes(action)) {
      return true;
    }
    await this.logSecurityEvent('permission_denied', { userId, resource, action });
    return false;
  }

  async logAuditEvent(eventType, category, metadata = {}) {
    try {
      const metaStr = JSON.stringify(metadata);
      await this.runQuery(
        'INSERT INTO audit_logs (action, resource_type, details, user_id, ip_address, user_agent)' +
         `
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          eventType,
          category,
          metaStr,
          metadata.userId || null,
          metadata.ip || null,
          metadata.userAgent || null,
        ],
        'run',
      );
    } catch (error) {
      this.logger.error(`Failed to log audit event: ${error.message}`);
    }
  }

  async logSecurityEvent(eventType, metadata = {}) {
    return this.logAuditEvent(eventType, 'security', metadata);
  }

  hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  generateSessionId() {
    return crypto.randomBytes(16).toString('hex');
  }

  startSessionCleanup() {
    setInterval(async() => {
      try {
        if (!this.db.pool) {
          return;
        }
        const result = await this.runQuery(
          'UPDATE user_sessions SET is_active = false WHERE expires_at < NOW() AND is_active = true',
          [],
          'run',
        );
        if (result.changes > 0) {
          this.logger.info('Cleaned up expired sessions', { count: result.changes });
        }
      } catch (error) {
        this.logger.error('Session cleanup failed', { error: error.message });
      }
    }, 15 * 60 * 1000);
  }

  async getAuthStats() {
    try {
      const activeSessions = await this.runQuery('SELECT COUNT(*) as count FROM user_sessions WHERE is_active = true', [], 'get');
      const validSessions = await this.runQuery('SELECT COUNT(*) as count FROM user_sessions WHERE expires_at > NOW()', [], 'get');
      const activeUsers = await this.runQuery('SELECT COUNT(DISTINCT user_id) as count FROM user_sessions WHERE is_active = true', [], 'get');
      const interval = 'NOW() - INTERVAL \'24 HOURS\'';
      const authEvents = await this.runQuery(`SELECT COUNT(*) as count FROM audit_logs WHERE resource_type = 'authentication' AND created_at > ${interval}`, [], 'get');
      const securityEvents = await this.runQuery(`SELECT COUNT(*) as count FROM audit_logs WHERE resource_type = 'security' AND created_at > ${interval}`, [], 'get');

      return {
        active_sessions: activeSessions?.count || 0,
        valid_sessions: validSessions?.count || 0,
        active_users: activeUsers?.count || 0,
        auth_events_24h: authEvents?.count || 0,
        security_events_24h: securityEvents?.count || 0,
      };
    } catch {
      return {};
    }
  }

  async close() {
    if (this.db) {
      await this.db.close();
    }
  }
}
