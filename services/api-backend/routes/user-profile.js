/**
 * User Profile API Routes
 *
 * Provides user-facing endpoints for:
 * - Profile retrieval and updates
 * - User preference management
 * - Avatar/profile picture uploads
 * - Notification preferences
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 3.1, 3.2, 3.8, 3.9
 * - Provides endpoints for user profile retrieval and updates
 * - Supports user preference storage (theme, language, notifications)
 * - Supports user avatar/profile picture uploads
 * - Implements user notification preferences
 *
 * @fileoverview User profile management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { UserProfileService } from '../services/user-profile-service.js';
import {
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
} from '../utils/input-validation.js';
import logger from '../logger.js';

const router = express.Router();
let userProfileService = null;

/**
 * Initialize the user profile service
 * Called once during server startup
 */
export async function initializeUserProfileService() {
  try {
    userProfileService = new UserProfileService();
    await userProfileService.initialize();
    logger.info('[UserProfileRoutes] User profile service initialized');
  } catch (error) {
    logger.error(
      '[UserProfileRoutes] Failed to initialize user profile service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * GET /api/users/profile
 *
 * Get current user's profile information
 *
 * Returns:
 * - User ID
 * - Email
 * - Profile information (name, avatar, preferences)
 * - Account metadata
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/profile', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access profile information',
      });
    }

    if (!userProfileService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User profile service is not initialized',
      });
    }

    const userId = req.user.sub;
    const profile = await userProfileService.getUserProfile(userId);

    logger.debug('[UserProfile] Profile retrieved', {
      userId,
    });

    res.json({
      success: true,
      data: profile,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserProfile] Error retrieving profile', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User profile not found',
      });
    }

    res.status(500).json({
      error: 'Failed to retrieve profile',
      code: 'PROFILE_RETRIEVAL_FAILED',
      message: 'An error occurred while retrieving your profile',
    });
  }
});

/**
 * PUT /api/users/profile
 *
 * Update current user's profile information
 *
 * Request body:
 * {
 *   "profile": {
 *     "firstName": "John",
 *     "lastName": "Doe",
 *     "nickname": "johndoe",
 *     "avatar": "https://example.com/avatar.jpg",
 *     "preferences": {
 *       "theme": "dark",
 *       "language": "en",
 *       "notifications": true
 *     }
 *   }
 * }
 *
 * Returns:
 * - Updated user profile
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put('/profile', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to update profile',
      });
    }

    if (!userProfileService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User profile service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { profile } = req.body;

    // Validate request body
    if (!profile || typeof profile !== 'object') {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_REQUEST',
        message: 'Profile object is required',
      });
    }

    // Validate and sanitize profile data
    const validation = validateAndSanitizeProfile(profile);
    if (!validation.valid) {
      logger.warn('[UserProfile] Profile validation failed', {
        userId,
        error: validation.error,
      });

      return res.status(400).json({
        error: 'Validation error',
        code: 'VALIDATION_ERROR',
        message: validation.error,
      });
    }

    const updatedProfile = await userProfileService.updateUserProfile(userId, {
      profile: validation.data,
    });

    logger.info('[UserProfile] Profile updated', {
      userId,
    });

    res.json({
      success: true,
      data: updatedProfile,
      message: 'Profile updated successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserProfile] Error updating profile', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User profile not found',
      });
    }

    if (error.message.includes('Invalid')) {
      return res.status(400).json({
        error: 'Validation error',
        code: 'VALIDATION_ERROR',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Failed to update profile',
      code: 'PROFILE_UPDATE_FAILED',
      message: 'An error occurred while updating your profile',
    });
  }
});

/**
 * GET /api/users/preferences
 *
 * Get current user's preferences
 *
 * Returns:
 * - Theme preference (light/dark)
 * - Language preference
 * - Notification settings
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/preferences', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access preferences',
      });
    }

    if (!userProfileService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User profile service is not initialized',
      });
    }

    const userId = req.user.sub;
    const preferences = await userProfileService.getUserPreferences(userId);

    logger.debug('[UserProfile] Preferences retrieved', {
      userId,
    });

    res.json({
      success: true,
      data: preferences,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserProfile] Error retrieving preferences', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User not found',
      });
    }

    res.status(500).json({
      error: 'Failed to retrieve preferences',
      code: 'PREFERENCES_RETRIEVAL_FAILED',
      message: 'An error occurred while retrieving your preferences',
    });
  }
});

/**
 * PUT /api/users/preferences
 *
 * Update current user's preferences
 *
 * Request body:
 * {
 *   "theme": "dark",
 *   "language": "en",
 *   "notifications": true
 * }
 *
 * Returns:
 * - Updated preferences
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put('/preferences', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to update preferences',
      });
    }

    if (!userProfileService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User profile service is not initialized',
      });
    }

    const userId = req.user.sub;
    const preferences = req.body;

    // Validate request body
    if (!preferences || typeof preferences !== 'object') {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_REQUEST',
        message: 'Preferences object is required',
      });
    }

    // Validate and sanitize preferences
    const validation = validateAndSanitizePreferences(preferences);
    if (!validation.valid) {
      logger.warn('[UserProfile] Preferences validation failed', {
        userId,
        error: validation.error,
      });

      return res.status(400).json({
        error: 'Validation error',
        code: 'VALIDATION_ERROR',
        message: validation.error,
      });
    }

    const updatedPreferences = await userProfileService.updateUserPreferences(
      userId,
      validation.data,
    );

    logger.info('[UserProfile] Preferences updated', {
      userId,
    });

    res.json({
      success: true,
      data: updatedPreferences,
      message: 'Preferences updated successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserProfile] Error updating preferences', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User not found',
      });
    }

    if (error.message.includes('Invalid')) {
      return res.status(400).json({
        error: 'Validation error',
        code: 'VALIDATION_ERROR',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Failed to update preferences',
      code: 'PREFERENCES_UPDATE_FAILED',
      message: 'An error occurred while updating your preferences',
    });
  }
});

/**
 * PUT /api/users/avatar
 *
 * Update current user's avatar/profile picture
 *
 * Request body:
 * {
 *   "avatarUrl": "https://example.com/avatar.jpg"
 * }
 *
 * Returns:
 * - Updated user profile with new avatar
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put('/avatar', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to update avatar',
      });
    }

    if (!userProfileService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User profile service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { avatarUrl } = req.body;

    // Validate request body
    if (!avatarUrl || typeof avatarUrl !== 'string') {
      return res.status(400).json({
        error: 'Invalid request',
        code: 'INVALID_REQUEST',
        message: 'Avatar URL is required and must be a string',
      });
    }

    const updatedProfile = await userProfileService.updateUserAvatar(
      userId,
      avatarUrl,
    );

    logger.info('[UserProfile] Avatar updated', {
      userId,
    });

    res.json({
      success: true,
      data: updatedProfile,
      message: 'Avatar updated successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserProfile] Error updating avatar', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User not found',
      });
    }

    if (error.message.includes('Invalid')) {
      return res.status(400).json({
        error: 'Validation error',
        code: 'VALIDATION_ERROR',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Failed to update avatar',
      code: 'AVATAR_UPDATE_FAILED',
      message: 'An error occurred while updating your avatar',
    });
  }
});

export default router;
