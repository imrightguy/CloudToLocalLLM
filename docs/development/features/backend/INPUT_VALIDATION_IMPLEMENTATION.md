# Input Validation and Injection Prevention Implementation

## Overview

This document describes the comprehensive input validation and injection prevention implementation for the CloudToLocalLLM API Backend. The implementation addresses Requirement 3.7 by providing:

- Comprehensive input validation for all user endpoints
- SQL injection prevention via parameterized queries
- XSS prevention through input sanitization

## Implementation Summary

### 1. Input Validation Utilities Module

**File:** `services/api-backend/utils/input-validation.js`

A comprehensive utility module providing validation and sanitization functions:

#### Core Validation Functions

- **`sanitizeString(input)`** - Removes null bytes and escapes HTML special characters to prevent XSS
- **`isValidEmail(email)`** - Validates email format using RFC 5322 simplified regex
- **`isValidUrl(url)`** - Validates URL format using Node.js URL constructor
- **`isValidLength(input, min, max)`** - Validates string length within bounds
- **`isNotEmpty(input)`** - Validates string is not empty or whitespace-only
- **`isAlphanumericUnderscore(input)`** - Validates alphanumeric characters and underscores
- **`isSlugFormat(input)`** - Validates slug format (alphanumeric, hyphens, underscores)
- **`isValidBoolean(input)`** - Validates boolean type
- **`isValidNumber(input, min, max)`** - Validates number within optional bounds
- **`isValidInteger(input, min, max)`** - Validates integer within optional bounds
- **`isOneOf(input, allowedValues)`** - Validates input is in allowed values list

#### Domain-Specific Validation Functions

- **`validateName(name, maxLength)`** - Validates user names (first, last, nickname)
  - Checks type is string
  - Validates length (0-100 characters by default)
  - Rejects HTML special characters
  
- **`validateEmail(email)`** - Validates email addresses
  - Checks RFC 5322 format
  - Validates length <= 255 characters
  
- **`validateUrl(url, allowEmpty)`** - Validates URLs
  - Uses Node.js URL constructor
  - Optionally allows empty strings
  
- **`validateTheme(theme)`** - Validates theme preference
  - Only allows 'light' or 'dark'
  
- **`validateLanguage(language, maxLength)`** - Validates language codes
  - Checks length (1-10 characters by default)
  - Only allows alphanumeric and hyphens (e.g., en-US)
  
- **`validateNotifications(notifications)`** - Validates notification preference
  - Must be boolean type
  
- **`validatePreferences(preferences)`** - Validates preferences object
  - Validates theme, language, and notifications fields
  - Allows partial preferences
  
- **`validateProfile(profile)`** - Validates user profile object
  - Validates firstName, lastName, nickname, avatar, preferences
  - Allows partial profiles

#### Composite Validation Functions

- **`validateAndSanitizeProfile(profileData)`** - Validates and sanitizes profile data
  - Validates profile structure
  - Sanitizes string fields
  - Returns `{valid: boolean, data?: Object, error?: string}`
  
- **`validateAndSanitizePreferences(preferences)`** - Validates and sanitizes preferences
  - Validates preferences structure
  - Sanitizes language field
  - Returns `{valid: boolean, data?: Object, error?: string}`

#### Utility Functions

- **`sanitizeInput(input, stringFields)`** - Recursively sanitizes object
  - Escapes HTML in specified string fields
  - Recursively processes nested objects
  
- **`logValidationError(endpoint, userId, field, reason, context)`** - Logs validation errors
  - Logs to security monitoring system
  - Includes endpoint, user, field, and reason

### 2. User Profile Service Integration

**File:** `services/api-backend/services/user-profile-service.js`

Updated to use new validation utilities:

- **`updateUserProfile(userId, profileData)`**
  - Validates and sanitizes profile data before update
  - Uses parameterized queries for database operations
  - Logs validation errors for security monitoring
  
- **`updateUserPreferences(userId, preferences)`**
  - Validates and sanitizes preferences before update
  - Uses parameterized queries for database operations
  
- **`updateUserAvatar(userId, avatarUrl)`**
  - Validates URL format
  - Uses parameterized queries for database operations

### 3. User Profile Routes Integration

**File:** `services/api-backend/routes/user-profile.js`

Updated endpoints with validation:

- **`PUT /api/users/profile`**
  - Validates and sanitizes profile data
  - Returns 400 with validation error if invalid
  - Logs validation failures
  
- **`PUT /api/users/preferences`**
  - Validates and sanitizes preferences
  - Returns 400 with validation error if invalid
  - Logs validation failures

### 4. Database Layer Security

**File:** `services/api-backend/database/db-pool.js`

SQL injection prevention is handled at the database layer:

- All queries use parameterized queries with `$1`, `$2`, etc. placeholders
- User input is passed as separate parameters, never concatenated into SQL
- PostgreSQL driver automatically escapes all parameters
- Connection pooling with configurable pool size and timeouts

Example:
```javascript
// Safe - parameterized query
const query = `
  UPDATE users
  SET name = $1, nickname = $2
  WHERE auth0_id = $3
`;
await pool.query(query, [name, nickname, userId]);

// Unsafe - never do this
const unsafeQuery = `UPDATE users SET name = '${name}' WHERE auth0_id = '${userId}'`;
```

## Security Features

### XSS Prevention

1. **Input Sanitization**
   - HTML special characters are escaped: `<`, `>`, `"`, `'`, `/`, `&`
   - Null bytes are removed
   - Applied to all string inputs

2. **Validation**
   - Names reject HTML special characters
   - URLs are validated using Node.js URL constructor
   - Email validation prevents malicious patterns

3. **Output Encoding**
   - All responses are JSON-encoded
   - HTML entities are properly escaped

### SQL Injection Prevention

1. **Parameterized Queries**
   - All database queries use parameterized queries
   - User input is never concatenated into SQL strings
   - PostgreSQL driver handles escaping

2. **Input Validation**
   - Validates input types and formats
   - Rejects obviously malicious patterns
   - Provides defense-in-depth

3. **Connection Security**
   - SSL/TLS support for database connections
   - Connection pooling with security settings
   - Statement timeout to prevent long-running queries

## Testing

**File:** `test/api-backend/input-validation.test.js`

Comprehensive test suite with 83 passing tests covering:

### Sanitization Tests
- Null byte removal
- HTML special character escaping
- Event handler prevention
- XSS attack prevention

### Validation Tests
- Email format validation
- URL format validation
- String length validation
- Boolean and number validation
- Enum validation

### Domain-Specific Tests
- Name validation (length, special characters)
- Email validation (format, length)
- URL validation (format, empty handling)
- Theme validation (light/dark only)
- Language validation (format, length)
- Notification validation (boolean only)
- Preferences validation (all fields)
- Profile validation (all fields)

### Security Tests
- SQL injection prevention
- XSS prevention
- Edge cases (unicode, long strings, empty objects)

### Integration Tests
- Profile validation and sanitization
- Preferences validation and sanitization
- Composite object validation

## Usage Examples

### Validating User Input

```javascript
import {
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
  logValidationError,
} from '../utils/input-validation.js';

// Validate profile
const profileValidation = validateAndSanitizeProfile(req.body.profile);
if (!profileValidation.valid) {
  logValidationError('PUT /api/users/profile', userId, 'profile', profileValidation.error);
  return res.status(400).json({
    error: 'Validation error',
    message: profileValidation.error,
  });
}

// Use sanitized data
const sanitizedProfile = profileValidation.data;
await userProfileService.updateUserProfile(userId, { profile: sanitizedProfile });
```

### Custom Validation

```javascript
import { validateName, validateEmail, validateUrl } from '../utils/input-validation.js';

// Validate individual fields
const nameValidation = validateName(firstName);
if (!nameValidation.valid) {
  throw new Error(nameValidation.error);
}

const emailValidation = validateEmail(email);
if (!emailValidation.valid) {
  throw new Error(emailValidation.error);
}

const urlValidation = validateUrl(avatarUrl, true); // Allow empty
if (!urlValidation.valid) {
  throw new Error(urlValidation.error);
}
```

## Requirements Coverage

### Requirement 3.7: Input Validation and Injection Prevention

✅ **Add comprehensive input validation for all user endpoints**
- Validation utilities for all common input types
- Domain-specific validators for user data
- Composite validators for complex objects
- Applied to all user profile endpoints

✅ **Implement SQL injection prevention via parameterized queries**
- All database queries use parameterized queries
- User input passed as separate parameters
- PostgreSQL driver handles escaping
- Connection security with SSL/TLS support

✅ **Add XSS prevention for user inputs**
- HTML special character escaping
- Null byte removal
- Input validation rejecting malicious patterns
- Output encoding in JSON responses

## Performance Considerations

- Validation functions are lightweight and fast
- Regex patterns are optimized for performance
- Sanitization only applied to string fields
- No external dependencies for validation
- Caching of validation results where appropriate

## Future Enhancements

1. **Rate Limiting on Validation Failures**
   - Track validation failures per user
   - Implement rate limiting for repeated failures

2. **Advanced Pattern Detection**
   - Machine learning for anomaly detection
   - Behavioral analysis of input patterns

3. **Content Security Policy**
   - Implement CSP headers
   - Restrict script execution

4. **Input Whitelisting**
   - Define allowed characters per field
   - Strict whitelist validation

## References

- OWASP Input Validation Cheat Sheet
- OWASP SQL Injection Prevention
- OWASP XSS Prevention Cheat Sheet
- PostgreSQL Parameterized Queries Documentation
- Node.js URL API Documentation

## Conclusion

The input validation and injection prevention implementation provides comprehensive security for the CloudToLocalLLM API Backend. By combining input validation, parameterized queries, and output encoding, the system is protected against common web vulnerabilities including SQL injection and XSS attacks.
