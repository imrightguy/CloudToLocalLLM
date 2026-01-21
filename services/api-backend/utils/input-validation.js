/**
 * Input Validation Utilities
 *
 * Provides comprehensive input validation and sanitization for all user endpoints.
 * Implements:
 * - Type validation
 * - String length validation
 * - Email validation
 * - URL validation
 * - XSS prevention through sanitization
 * - SQL injection prevention (via parameterized queries)
 * - Custom validation rules
 *
 * Validates: Requirements 3.7
 * - Add comprehensive input validation for all user endpoints
 * - Implement SQL injection prevention via parameterized queries
 * - Add XSS prevention for user inputs
 *
 * @fileoverview Input validation and sanitization utilities
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Validation error class
 */
export class ValidationError extends Error {
  constructor(message, field = null, code = 'VALIDATION_ERROR') {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
    this.code = code;
  }
}

/**
 * Sanitize string input to prevent XSS attacks
 * Removes or escapes potentially dangerous characters
 *
 * @param {string} input - Input string to sanitize
 * @returns {string} Sanitized string
 */
export function sanitizeString(input) {
  if (typeof input !== 'string') {
    return input;
  }

  // Remove null bytes
  let sanitized = input.replace(/\0/g, '');

  // Escape HTML special characters to prevent XSS
  const htmlEscapeMap = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
  };

  sanitized = sanitized.replace(/[&<>"'/]/g, (char) => htmlEscapeMap[char]);

  return sanitized;
}

/**
 * Validate email format
 *
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid email format
 */
export function isValidEmail(email) {
  if (typeof email !== 'string') {
    return false;
  }

  // RFC 5322 simplified email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email) && email.length <= 255;
}

/**
 * Validate URL format
 *
 * @param {string} url - URL to validate
 * @returns {boolean} True if valid URL format
 */
export function isValidUrl(url) {
  if (typeof url !== 'string') {
    return false;
  }

  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

/**
 * Validate string length
 *
 * @param {string} input - String to validate
 * @param {number} minLength - Minimum length (default: 0)
 * @param {number} maxLength - Maximum length (default: 1000)
 * @returns {boolean} True if length is valid
 */
export function isValidLength(input, minLength = 0, maxLength = 1000) {
  if (typeof input !== 'string') {
    return false;
  }

  return input.length >= minLength && input.length <= maxLength;
}

/**
 * Validate that input is not empty or whitespace only
 *
 * @param {string} input - String to validate
 * @returns {boolean} True if not empty
 */
export function isNotEmpty(input) {
  if (typeof input !== 'string') {
    return false;
  }

  return input.trim().length > 0;
}

/**
 * Validate string contains only alphanumeric characters and underscores
 *
 * @param {string} input - String to validate
 * @returns {boolean} True if valid
 */
export function isAlphanumericUnderscore(input) {
  if (typeof input !== 'string') {
    return false;
  }

  return /^[a-zA-Z0-9_]+$/.test(input);
}

/**
 * Validate string contains only alphanumeric characters, hyphens, and underscores
 *
 * @param {string} input - String to validate
 * @returns {boolean} True if valid
 */
export function isSlugFormat(input) {
  if (typeof input !== 'string') {
    return false;
  }

  return /^[a-zA-Z0-9_-]+$/.test(input);
}

/**
 * Validate string contains only alphanumeric characters, hyphens, and underscores
 *
 * @param {*} input - Input to validate
 * @returns {boolean} True if valid boolean
 */
export function isValidBoolean(input) {
  return typeof input === 'boolean';
}

/**
 * Validate that input is a valid number
 *
 * @param {*} input - Input to validate
 * @param {number} min - Minimum value (optional)
 * @param {number} max - Maximum value (optional)
 * @returns {boolean} True if valid number
 */
export function isValidNumber(input, min = null, max = null) {
  if (typeof input !== 'number' || isNaN(input)) {
    return false;
  }

  if (min !== null && input < min) {
    return false;
  }

  if (max !== null && input > max) {
    return false;
  }

  return true;
}

/**
 * Validate that input is a valid integer
 *
 * @param {*} input - Input to validate
 * @param {number} min - Minimum value (optional)
 * @param {number} max - Maximum value (optional)
 * @returns {boolean} True if valid integer
 */
export function isValidInteger(input, min = null, max = null) {
  if (!Number.isInteger(input)) {
    return false;
  }

  if (min !== null && input < min) {
    return false;
  }

  if (max !== null && input > max) {
    return false;
  }

  return true;
}

/**
 * Validate that input is one of allowed values
 *
 * @param {*} input - Input to validate
 * @param {Array} allowedValues - Array of allowed values
 * @returns {boolean} True if input is in allowed values
 */
export function isOneOf(input, allowedValues) {
  return allowedValues.includes(input);
}

/**
 * Validate user name (first name, last name, nickname)
 *
 * @param {string} name - Name to validate
 * @param {number} maxLength - Maximum length (default: 100)
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateName(name, maxLength = 100) {
  if (typeof name !== 'string') {
    return { valid: false, error: 'Name must be a string' };
  }

  if (!isValidLength(name, 0, maxLength)) {
    return {
      valid: false,
      error: `Name must be between 0 and ${maxLength} characters`,
    };
  }

  // Check for potentially malicious patterns
  if (name.includes('<') || name.includes('>') || name.includes('"')) {
    return { valid: false, error: 'Name contains invalid characters' };
  }

  return { valid: true };
}

/**
 * Validate email address
 *
 * @param {string} email - Email to validate
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateEmail(email) {
  if (typeof email !== 'string') {
    return { valid: false, error: 'Email must be a string' };
  }

  if (!isValidEmail(email)) {
    return { valid: false, error: 'Invalid email format' };
  }

  return { valid: true };
}

/**
 * Validate URL
 *
 * @param {string} url - URL to validate
 * @param {boolean} allowEmpty - Allow empty string (default: false)
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateUrl(url, allowEmpty = false) {
  if (typeof url !== 'string') {
    return { valid: false, error: 'URL must be a string' };
  }

  if (allowEmpty && url === '') {
    return { valid: true };
  }

  if (!isValidUrl(url)) {
    return { valid: false, error: 'Invalid URL format' };
  }

  return { valid: true };
}

/**
 * Validate theme preference
 *
 * @param {string} theme - Theme to validate
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateTheme(theme) {
  const validThemes = ['light', 'dark'];

  if (!isOneOf(theme, validThemes)) {
    return {
      valid: false,
      error: `Theme must be one of: ${validThemes.join(', ')}`,
    };
  }

  return { valid: true };
}

/**
 * Validate language code
 *
 * @param {string} language - Language code to validate
 * @param {number} maxLength - Maximum length (default: 10)
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateLanguage(language, maxLength = 10) {
  if (typeof language !== 'string') {
    return { valid: false, error: 'Language must be a string' };
  }

  if (!isValidLength(language, 1, maxLength)) {
    return {
      valid: false,
      error: `Language must be between 1 and ${maxLength} characters`,
    };
  }

  // Language codes should be alphanumeric with hyphens (e.g., en-US)
  if (!/^[a-zA-Z0-9-]+$/.test(language)) {
    return { valid: false, error: 'Language code contains invalid characters' };
  }

  return { valid: true };
}

/**
 * Validate notification preference
 *
 * @param {*} notifications - Notification preference to validate
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateNotifications(notifications) {
  if (!isValidBoolean(notifications)) {
    return { valid: false, error: 'Notifications must be a boolean' };
  }

  return { valid: true };
}

/**
 * Validate user preferences object
 *
 * @param {Object} preferences - Preferences object to validate
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validatePreferences(preferences) {
  if (typeof preferences !== 'object' || preferences === null) {
    return { valid: false, error: 'Preferences must be an object' };
  }

  // Validate theme if provided
  if (preferences.theme !== undefined) {
    const themeValidation = validateTheme(preferences.theme);
    if (!themeValidation.valid) {
      return themeValidation;
    }
  }

  // Validate language if provided
  if (preferences.language !== undefined) {
    const languageValidation = validateLanguage(preferences.language);
    if (!languageValidation.valid) {
      return languageValidation;
    }
  }

  // Validate notifications if provided
  if (preferences.notifications !== undefined) {
    const notificationsValidation = validateNotifications(
      preferences.notifications,
    );
    if (!notificationsValidation.valid) {
      return notificationsValidation;
    }
  }

  return { valid: true };
}

/**
 * Validate user profile object
 *
 * @param {Object} profile - Profile object to validate
 * @returns {Object} Validation result {valid: boolean, error?: string}
 */
export function validateProfile(profile) {
  if (typeof profile !== 'object' || profile === null) {
    return { valid: false, error: 'Profile must be an object' };
  }

  // Validate firstName if provided
  if (profile.firstName !== undefined) {
    const nameValidation = validateName(profile.firstName);
    if (!nameValidation.valid) {
      return { valid: false, error: `First name: ${nameValidation.error}` };
    }
  }

  // Validate lastName if provided
  if (profile.lastName !== undefined) {
    const nameValidation = validateName(profile.lastName);
    if (!nameValidation.valid) {
      return { valid: false, error: `Last name: ${nameValidation.error}` };
    }
  }

  // Validate nickname if provided
  if (profile.nickname !== undefined) {
    if (typeof profile.nickname !== 'string') {
      return { valid: false, error: 'Nickname must be a string' };
    }

    if (!isValidLength(profile.nickname, 0, 100)) {
      return {
        valid: false,
        error: 'Nickname must be between 0 and 100 characters',
      };
    }
  }

  // Validate avatar if provided
  if (profile.avatar !== undefined) {
    const avatarValidation = validateUrl(profile.avatar, true); // Allow empty
    if (!avatarValidation.valid) {
      return { valid: false, error: `Avatar: ${avatarValidation.error}` };
    }
  }

  // Validate preferences if provided
  if (profile.preferences !== undefined) {
    const preferencesValidation = validatePreferences(profile.preferences);
    if (!preferencesValidation.valid) {
      return preferencesValidation;
    }
  }

  return { valid: true };
}

/**
 * Sanitize user input object
 * Removes potentially dangerous content while preserving data
 *
 * @param {Object} input - Input object to sanitize
 * @param {Array<string>} stringFields - Fields that should be treated as strings
 * @returns {Object} Sanitized object
 */
export function sanitizeInput(input, stringFields = []) {
  if (typeof input !== 'object' || input === null) {
    return input;
  }

  const sanitized = {};

  for (const [key, value] of Object.entries(input)) {
    if (stringFields.includes(key) && typeof value === 'string') {
      sanitized[key] = sanitizeString(value);
    } else if (
      typeof value === 'object' &&
      value !== null &&
      !Array.isArray(value)
    ) {
      // Recursively sanitize nested objects
      sanitized[key] = sanitizeInput(value, stringFields);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

/**
 * Validate and sanitize user profile update
 *
 * @param {Object} profileData - Profile data to validate and sanitize
 * @returns {Object} Result {valid: boolean, data?: Object, error?: string}
 */
export function validateAndSanitizeProfile(profileData) {
  if (typeof profileData !== 'object' || profileData === null) {
    return { valid: false, error: 'Profile data must be an object' };
  }

  // Validate profile structure
  const profileValidation = validateProfile(profileData);
  if (!profileValidation.valid) {
    return profileValidation;
  }

  // Sanitize string fields
  const stringFields = ['firstName', 'lastName', 'nickname', 'avatar'];
  const sanitized = sanitizeInput(profileData, stringFields);

  return { valid: true, data: sanitized };
}

/**
 * Validate and sanitize preferences update
 *
 * @param {Object} preferences - Preferences to validate and sanitize
 * @returns {Object} Result {valid: boolean, data?: Object, error?: string}
 */
export function validateAndSanitizePreferences(preferences) {
  if (typeof preferences !== 'object' || preferences === null) {
    return { valid: false, error: 'Preferences must be an object' };
  }

  // Validate preferences structure
  const preferencesValidation = validatePreferences(preferences);
  if (!preferencesValidation.valid) {
    return preferencesValidation;
  }

  // Sanitize language field if present
  const stringFields = ['language'];
  const sanitized = sanitizeInput(preferences, stringFields);

  return { valid: true, data: sanitized };
}

/**
 * Log validation error for security monitoring
 *
 * @param {string} endpoint - API endpoint
 * @param {string} userId - User ID (optional)
 * @param {string} field - Field that failed validation
 * @param {string} reason - Reason for validation failure
 * @param {Object} context - Additional context
 */
export function logValidationError(
  endpoint,
  userId,
  field,
  reason,
  context = {},
) {
  logger.warn('[InputValidation] Validation error', {
    endpoint,
    userId,
    field,
    reason,
    ...context,
  });
}

/**
 * Generic input validator
 *
 * @param {*} value - Value to validate
 * @param {string} name - Field name
 * @param {string} type - Expected type
 * @throws {Error} If validation fails
 */
export function validateInput(value, name, type) {
  // Handle uuid type check (string with specific format)
  if (type === 'uuid') {
    if (
      typeof value !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        value,
      )
    ) {
      throw new Error(`Invalid ${name}: expected UUID`);
    }
    return;
  }

  if (typeof value !== type) {
    throw new Error(`Invalid ${name}: expected ${type}, got ${typeof value}`);
  }
}

export default {
  ValidationError,
  sanitizeString,
  isValidEmail,
  isValidUrl,
  isValidLength,
  isNotEmpty,
  isAlphanumericUnderscore,
  isSlugFormat,
  isValidBoolean,
  isValidNumber,
  isValidInteger,
  isOneOf,
  validateName,
  validateEmail,
  validateUrl,
  validateTheme,
  validateLanguage,
  validateNotifications,
  validatePreferences,
  validateProfile,
  sanitizeInput,
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
  logValidationError,
  validateInput,
};
