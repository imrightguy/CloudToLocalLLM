/**
 * User Profile Service
 *
 * Handles user profile management including:
 * - Profile retrieval and updates
 * - User preferences (theme, language, notifications)
 * - Avatar/profile picture uploads
 * - Profile validation
 *
 * Validates: Requirements 3.1, 3.2, 3.8, 3.9
 * - Provides endpoints for user profile retrieval and updates
 * - Supports user preference storage (theme, language, notifications)
 * - Supports user avatar/profile picture uploads
 * - Implements user notification preferences
 *
 * @fileoverview User profile management service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { initializePool } from '../database/db-pool.js';
import {
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
  validateUrl,
  logValidationError,
} from '../utils/input-validation.js';

/**
 * UserProfileService
 * Manages user profile data and preferences
 */
export class UserProfileService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the service with database pool
   */
  async initialize() {
    try {
      this.pool = await initializePool();
      logger.info('[UserProfileService] Service initialized');
    } catch (error) {
      logger.error('[UserProfileService] Failed to initialize', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get user profile by user ID
   * @param {string} userId - JWT user ID
   * @returns {Promise<Object>} User profile object
   */
  async getUserProfile(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    try {
      const query = `
        SELECT 
          u.id,
          u.jwt_id,
          u.email,
          u.name,
          u.nickname,
          u.picture,
          u.email_verified,
          u.locale,
          u.created_at,
          u.updated_at,
          u.last_login,
          u.login_count,
          u.metadata,
          COALESCE(up.preferences, '{}'::jsonb) as preferences
        FROM users u
        LEFT JOIN user_preferences up ON u.id = up.user_id
        WHERE u.jwt_id = $1
      `;

      const result = await this.pool.query(query, [userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      const user = result.rows[0];

      return {
        id: user.id,
        jwtId: user.jwt_id,
        email: user.email,
        profile: {
          firstName: user.name ? user.name.split(' ')[0] : '',
          lastName: user.name ? user.name.split(' ').slice(1).join(' ') : '',
          nickname: user.nickname,
          avatar: user.picture,
          preferences: user.preferences || {
            theme: 'light',
            language: 'en',
            notifications: true,
          },
        },
        emailVerified: user.email_verified,
        locale: user.locale,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
        lastLogin: user.last_login,
        loginCount: user.login_count,
        metadata: user.metadata || {},
      };
    } catch (error) {
      logger.error('[UserProfileService] Error retrieving user profile', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update user profile
   * @param {string} userId - JWT user ID
   * @param {Object} profileData - Profile data to update
   * @returns {Promise<Object>} Updated user profile
   */
  async updateUserProfile(userId, profileData) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    if (!profileData || typeof profileData !== 'object') {
      throw new Error('Invalid profile data');
    }

    try {
      // Validate and sanitize profile data
      const validation = validateAndSanitizeProfile(profileData.profile || {});
      if (!validation.valid) {
        logValidationError(
          'PUT /api/users/profile',
          userId,
          'profile',
          validation.error,
        );
        throw new Error(validation.error);
      }

      // Use sanitized data
      const sanitizedProfileData = {
        profile: validation.data,
      };

      // Start transaction
      const client = await this.pool.connect();

      try {
        await client.query('BEGIN');

        // Update user basic info if provided
        if (sanitizedProfileData.profile) {
          const { firstName, lastName, nickname, avatar } =
            sanitizedProfileData.profile;
          const fullName = [firstName, lastName].filter(Boolean).join(' ');

          const updateQuery = `
            UPDATE users
            SET 
              name = COALESCE($1, name),
              nickname = COALESCE($2, nickname),
              picture = COALESCE($3, picture),
              updated_at = NOW()
            WHERE jwt_id = $4
            RETURNING *
          `;

          await client.query(updateQuery, [
            fullName || null,
            nickname || null,
            avatar || null,
            userId,
          ]);
        }

        // Update preferences if provided
        if (
          sanitizedProfileData.profile &&
          sanitizedProfileData.profile.preferences
        ) {
          const preferencesQuery = `
            INSERT INTO user_preferences (user_id, preferences, created_at, updated_at)
            SELECT u.id, $1::jsonb, NOW(), NOW()
            FROM users u
            WHERE u.jwt_id = $2
            ON CONFLICT (user_id) DO UPDATE
            SET preferences = $1::jsonb, updated_at = NOW()
          `;

          await client.query(preferencesQuery, [
            JSON.stringify(sanitizedProfileData.profile.preferences),
            userId,
          ]);
        }

        await client.query('COMMIT');

        // Retrieve and return updated profile
        return await this.getUserProfile(userId);
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[UserProfileService] Error updating user profile', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update user preferences
   * @param {string} userId - JWT user ID
   * @param {Object} preferences - Preferences object
   * @returns {Promise<Object>} Updated preferences
   */
  async updateUserPreferences(userId, preferences) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    if (!preferences || typeof preferences !== 'object') {
      throw new Error('Invalid preferences');
    }

    try {
      // Validate and sanitize preferences
      const validation = validateAndSanitizePreferences(preferences);
      if (!validation.valid) {
        logValidationError(
          'PUT /api/users/preferences',
          userId,
          'preferences',
          validation.error,
        );
        throw new Error(validation.error);
      }

      const sanitizedPreferences = validation.data;

      const query = `
        INSERT INTO user_preferences (user_id, preferences, created_at, updated_at)
        SELECT u.id, $1::jsonb, NOW(), NOW()
        FROM users u
        WHERE u.jwt_id = $2
        ON CONFLICT (user_id) DO UPDATE
        SET preferences = $1::jsonb, updated_at = NOW()
        RETURNING preferences
      `;

      const result = await this.pool.query(query, [
        JSON.stringify(sanitizedPreferences),
        userId,
      ]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      return result.rows[0].preferences;
    } catch (error) {
      logger.error('[UserProfileService] Error updating preferences', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get user preferences
   * @param {string} userId - JWT user ID
   * @returns {Promise<Object>} User preferences
   */
  async getUserPreferences(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    try {
      const query = `
        SELECT COALESCE(up.preferences, '{}'::jsonb) as preferences
        FROM users u
        LEFT JOIN user_preferences up ON u.id = up.user_id
        WHERE u.jwt_id = $1
      `;

      const result = await this.pool.query(query, [userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      return (
        result.rows[0].preferences || {
          theme: 'light',
          language: 'en',
          notifications: true,
        }
      );
    } catch (error) {
      logger.error('[UserProfileService] Error retrieving preferences', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update user avatar
   * @param {string} userId - JWT user ID
   * @param {string} avatarUrl - Avatar URL
   * @returns {Promise<Object>} Updated user profile
   */
  async updateUserAvatar(userId, avatarUrl) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    if (!avatarUrl || typeof avatarUrl !== 'string') {
      throw new Error('Invalid avatar URL');
    }

    // Validate URL format
    const urlValidation = validateUrl(avatarUrl, false);
    if (!urlValidation.valid) {
      logValidationError(
        'PUT /api/users/avatar',
        userId,
        'avatarUrl',
        urlValidation.error,
      );
      throw new Error(urlValidation.error);
    }

    try {
      const query = `
        UPDATE users
        SET picture = $1, updated_at = NOW()
        WHERE jwt_id = $2
        RETURNING *
      `;

      const result = await this.pool.query(query, [avatarUrl, userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      return await this.getUserProfile(userId);
    } catch (error) {
      logger.error('[UserProfileService] Error updating avatar', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate profile data
   * @private
   * @param {Object} profileData - Profile data to validate
   * @throws {Error} If validation fails
   */
  _validateProfileData(profileData) {
    if (profileData.profile) {
      const { firstName, lastName, nickname, avatar, preferences } =
        profileData.profile;

      // Validate names
      if (
        firstName !== undefined &&
        (typeof firstName !== 'string' || firstName.length > 100)
      ) {
        throw new Error('Invalid first name');
      }

      if (
        lastName !== undefined &&
        (typeof lastName !== 'string' || lastName.length > 100)
      ) {
        throw new Error('Invalid last name');
      }

      if (
        nickname !== undefined &&
        (typeof nickname !== 'string' || nickname.length > 100)
      ) {
        throw new Error('Invalid nickname');
      }

      // Validate avatar URL
      if (avatar !== undefined) {
        if (typeof avatar !== 'string') {
          throw new Error('Invalid avatar');
        }
        if (avatar.length > 0) {
          try {
            new URL(avatar);
          } catch {
            throw new Error('Invalid avatar URL format');
          }
        }
      }

      // Validate preferences
      if (preferences !== undefined) {
        this._validatePreferences(preferences);
      }
    }
  }

  /**
   * Validate preferences object
   * @private
   * @param {Object} preferences - Preferences to validate
   * @throws {Error} If validation fails
   */
  _validatePreferences(preferences) {
    if (typeof preferences !== 'object') {
      throw new Error('Preferences must be an object');
    }

    if (preferences.theme !== undefined) {
      if (!['light', 'dark'].includes(preferences.theme)) {
        throw new Error('Invalid theme. Must be "light" or "dark"');
      }
    }

    if (preferences.language !== undefined) {
      if (
        typeof preferences.language !== 'string' ||
        preferences.language.length > 10
      ) {
        throw new Error('Invalid language');
      }
    }

    if (preferences.notifications !== undefined) {
      if (typeof preferences.notifications !== 'boolean') {
        throw new Error('Notifications must be a boolean');
      }
    }
  }
}

export default UserProfileService;
