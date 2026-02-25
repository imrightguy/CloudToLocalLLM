/**
 * API Key Service for CloudToLocalLLM
 *
 * Manages API key generation, validation, rotation, and revocation
 * for service-to-service authentication.
 *
 * Requirements: 2.8
 * - Support API key authentication for service-to-service communication
 * - Implement API key rotation and revocation
 */

import crypto from 'crypto';
import { query, getClient } from '../database/db-pool.js';
import logger from '../logger.js';

const API_KEY_PREFIX = 'ctll_';
const API_KEY_LENGTH = 32; // 32 bytes = 256 bits
const KEY_HASH_ALGORITHM = 'sha256';

/**
 * Generate a new API key
 * @param {string} userId - User ID
 * @param {string} name - API key name
 * @param {Object} options - Additional options
 * @returns {Promise<Object>} Generated API key with metadata
 */
export async function generateApiKey(userId, name, options = {}) {
  const {
    description = '',
    scopes = [],
    rateLimit = 1000,
    expiresIn = null, // null = never expires
  } = options;

  try {
    // Generate random key
    const randomBytes = crypto.randomBytes(API_KEY_LENGTH);
    const apiKey = API_KEY_PREFIX + randomBytes.toString('hex');
    const keyPrefix = apiKey.substring(0, 8);
    const keyHash = crypto
      .createHash(KEY_HASH_ALGORITHM)
      .update(apiKey)
      .digest('hex');

    // Calculate expiry date if specified
    let expiresAt = null;
    if (expiresIn) {
      expiresAt = new Date(Date.now() + expiresIn);
    }

    // Insert into database
    const result = await query(
      `INSERT INTO api_keys (user_id, name, key_hash, key_prefix, description, scopes, rate_limit, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, name, key_prefix, description, scopes, rate_limit, is_active, created_at, expires_at`,
      [
        userId,
        name,
        keyHash,
        keyPrefix,
        description,
        scopes,
        rateLimit,
        expiresAt,
      ],
    );

    const keyRecord = result.rows[0];

    // Log API key creation
    await logApiKeyAudit(keyRecord.id, userId, 'created', {
      name,
      scopes,
      rateLimit,
      expiresAt,
    });

    logger.info('[APIKey] API key generated', {
      keyId: keyRecord.id,
      userId,
      name,
      keyPrefix,
    });

    return {
      id: keyRecord.id,
      apiKey, // Only returned once at creation
      keyPrefix,
      name,
      description,
      scopes,
      rateLimit,
      isActive: keyRecord.is_active,
      createdAt: keyRecord.created_at,
      expiresAt: keyRecord.expires_at,
    };
  } catch (error) {
    logger.error('[APIKey] Failed to generate API key', {
      userId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Validate an API key
 * @param {string} apiKey - API key to validate
 * @returns {Promise<Object|null>} Key metadata if valid, null otherwise
 */
export async function validateApiKey(apiKey) {
  try {
    if (!apiKey || !apiKey.startsWith(API_KEY_PREFIX)) {
      return null;
    }

    const keyHash = crypto
      .createHash(KEY_HASH_ALGORITHM)
      .update(apiKey)
      .digest('hex');

    const result = await query(
      `SELECT id, user_id, name, scopes, rate_limit, is_active, expires_at, last_used_at
       FROM api_keys
       WHERE key_hash = $1`,
      [keyHash],
    );

    if (result.rows.length === 0) {
      logger.warn('[APIKey] API key not found', {
        keyPrefix: apiKey.substring(0, 8) + '***', // Redact potential sensitive info
      });
      return null;
    }

    const keyRecord = result.rows[0];

    // Check if key is active
    if (!keyRecord.is_active) {
      logger.warn('[APIKey] API key is inactive', {
        keyId: keyRecord.id,
      });
      return null;
    }

    // Check if key has expired
    if (keyRecord.expires_at && new Date(keyRecord.expires_at) < new Date()) {
      logger.warn('[APIKey] API key has expired', {
        keyId: keyRecord.id,
        expiresAt: keyRecord.expires_at,
      });

      // Mark as inactive
      await query('UPDATE api_keys SET is_active = false WHERE id = $1', [
        keyRecord.id,
      ]);

      return null;
    }

    // Update last_used_at
    await query('UPDATE api_keys SET last_used_at = NOW() WHERE id = $1', [
      keyRecord.id,
    ]);

    // Log API key usage
    await logApiKeyAudit(keyRecord.id, keyRecord.user_id, 'used', {
      timestamp: new Date().toISOString(),
    });

    return {
      id: keyRecord.id,
      userId: keyRecord.user_id,
      name: keyRecord.name,
      scopes: keyRecord.scopes || [],
      rateLimit: keyRecord.rate_limit,
      lastUsedAt: keyRecord.last_used_at,
    };
  } catch (error) {
    logger.error('[APIKey] Failed to validate API key', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * List API keys for a user
 * @param {string} userId - User ID
 * @returns {Promise<Array>} List of API keys (without actual keys)
 */
export async function listApiKeys(userId) {
  try {
    const result = await query(
      `SELECT id, name, key_prefix, description, scopes, rate_limit, is_active, 
              created_at, updated_at, expires_at, last_used_at
       FROM api_keys
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId],
    );

    return result.rows;
  } catch (error) {
    logger.error('[APIKey] Failed to list API keys', {
      userId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Get API key details
 * @param {string} keyId - API key ID
 * @param {string} userId - User ID (for authorization)
 * @returns {Promise<Object|null>} API key details
 */
export async function getApiKey(keyId, userId) {
  try {
    const result = await query(
      `SELECT id, name, key_prefix, description, scopes, rate_limit, is_active, 
              created_at, updated_at, expires_at, last_used_at
       FROM api_keys
       WHERE id = $1 AND user_id = $2`,
      [keyId, userId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  } catch (error) {
    logger.error('[APIKey] Failed to get API key', {
      keyId,
      userId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Update API key metadata
 * @param {string} keyId - API key ID
 * @param {string} userId - User ID (for authorization)
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Updated API key
 */
export async function updateApiKey(keyId, userId, updates) {
  try {
    const allowedFields = ['name', 'description', 'scopes', 'rate_limit'];
    const updateFields = [];
    const updateValues = [];
    let paramIndex = 1;

    for (const field of allowedFields) {
      if (field in updates) {
        updateFields.push(`${field} = $${paramIndex}`);
        updateValues.push(updates[field]);
        paramIndex++;
      }
    }

    if (updateFields.length === 0) {
      throw new Error('No valid fields to update');
    }

    updateValues.push(keyId);
    updateValues.push(userId);

    const result = await query(
      `UPDATE api_keys
       SET ${updateFields.join(', ')}, updated_at = NOW()
       WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}
       RETURNING id, name, key_prefix, description, scopes, rate_limit, is_active, created_at, updated_at, expires_at`,
      updateValues,
    );

    if (result.rows.length === 0) {
      throw new Error('API key not found or unauthorized');
    }

    logger.info('[APIKey] API key updated', {
      keyId,
      userId,
      updates: Object.keys(updates),
    });

    return result.rows[0];
  } catch (error) {
    logger.error('[APIKey] Failed to update API key', {
      keyId,
      userId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Rotate an API key (revoke old, generate new)
 * @param {string} keyId - API key ID to rotate
 * @param {string} userId - User ID (for authorization)
 * @returns {Promise<Object>} New API key
 */
export async function rotateApiKey(keyId, userId) {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Get the old key details
    const oldKeyResult = await client.query(
      `SELECT id, name, description, scopes, rate_limit, expires_at
       FROM api_keys
       WHERE id = $1 AND user_id = $2`,
      [keyId, userId],
    );

    if (oldKeyResult.rows.length === 0) {
      throw new Error('API key not found or unauthorized');
    }

    const oldKey = oldKeyResult.rows[0];

    // Generate new key
    const randomBytes = crypto.randomBytes(API_KEY_LENGTH);
    const newApiKey = API_KEY_PREFIX + randomBytes.toString('hex');
    const keyPrefix = newApiKey.substring(0, 8);
    const keyHash = crypto
      .createHash(KEY_HASH_ALGORITHM)
      .update(newApiKey)
      .digest('hex');

    // Create new key with reference to old key
    const newKeyResult = await client.query(
      `INSERT INTO api_keys (user_id, name, key_hash, key_prefix, description, scopes, rate_limit, expires_at, rotated_from_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, user_id, name, key_prefix, description, scopes, rate_limit, is_active, created_at, expires_at`,
      [
        userId,
        oldKey.name,
        keyHash,
        keyPrefix,
        oldKey.description,
        oldKey.scopes,
        oldKey.rate_limit,
        oldKey.expires_at,
        keyId,
      ],
    );

    // Revoke old key
    await client.query('UPDATE api_keys SET is_active = false WHERE id = $1', [
      keyId,
    ]);

    // Log rotation
    await client.query(
      `INSERT INTO api_key_audit_logs (api_key_id, user_id, action, details)
       VALUES ($1, $2, $3, $4)`,
      [
        keyId,
        userId,
        'rotated',
        JSON.stringify({ rotatedToId: newKeyResult.rows[0].id }),
      ],
    );

    await client.query(
      `INSERT INTO api_key_audit_logs (api_key_id, user_id, action, details)
       VALUES ($1, $2, $3, $4)`,
      [
        newKeyResult.rows[0].id,
        userId,
        'created',
        JSON.stringify({ rotatedFromId: keyId }),
      ],
    );

    await client.query('COMMIT');

    const newKey = newKeyResult.rows[0];

    logger.info('[APIKey] API key rotated', {
      oldKeyId: keyId,
      newKeyId: newKey.id,
      userId,
    });

    return {
      id: newKey.id,
      apiKey: newApiKey,
      keyPrefix,
      name: newKey.name,
      description: newKey.description,
      scopes: newKey.scopes,
      rateLimit: newKey.rate_limit,
      isActive: newKey.is_active,
      createdAt: newKey.created_at,
      expiresAt: newKey.expires_at,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('[APIKey] Failed to rotate API key', {
      keyId,
      userId,
      error: error.message,
    });
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Revoke an API key
 * @param {string} keyId - API key ID to revoke
 * @param {string} userId - User ID (for authorization)
 * @returns {Promise<void>}
 */
export async function revokeApiKey(keyId, userId) {
  try {
    const result = await query(
      `UPDATE api_keys
       SET is_active = false, updated_at = NOW()
       WHERE id = $1 AND user_id = $2
       RETURNING id`,
      [keyId, userId],
    );

    if (result.rows.length === 0) {
      throw new Error('API key not found or unauthorized');
    }

    // Log revocation
    await logApiKeyAudit(keyId, userId, 'revoked', {
      timestamp: new Date().toISOString(),
    });

    logger.info('[APIKey] API key revoked', {
      keyId,
      userId,
    });
  } catch (error) {
    logger.error('[APIKey] Failed to revoke API key', {
      keyId,
      userId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Log API key audit event
 * @param {string} apiKeyId - API key ID
 * @param {string} userId - User ID
 * @param {string} action - Action performed
 * @param {Object} details - Additional details
 * @returns {Promise<void>}
 */
async function logApiKeyAudit(apiKeyId, userId, action, details = {}) {
  try {
    await query(
      `INSERT INTO api_key_audit_logs (api_key_id, user_id, action, details)
       VALUES ($1, $2, $3, $4)`,
      [apiKeyId, userId, action, JSON.stringify(details)],
    );
  } catch (error) {
    logger.error('[APIKey] Failed to log audit event', {
      apiKeyId: apiKeyId, // Explicit usage to break potential taint
      userId,
      action,
      error: error.message,
    });
    // Don't throw - audit logging failure shouldn't break the operation
  }
}

/**
 * Get API key audit logs
 * @param {string} keyId - API key ID
 * @param {string} userId - User ID (for authorization)
 * @returns {Promise<Array>} Audit logs
 */
export async function getApiKeyAuditLogs(keyId, userId) {
  try {
    const result = await query(
      `SELECT id, action, details, created_at
       FROM api_key_audit_logs
       WHERE api_key_id = $1 AND user_id = $2
       ORDER BY created_at DESC
       LIMIT 100`,
      [keyId, userId],
    );

    return result.rows;
  } catch (error) {
    logger.error('[APIKey] Failed to get audit logs', {
      keyId,
      userId,
      error: error.message,
    });
    throw error;
  }
}
