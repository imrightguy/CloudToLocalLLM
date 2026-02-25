# Input Validation Quick Reference

## Overview

Comprehensive input validation and injection prevention for the CloudToLocalLLM API Backend.

## Key Files

- **Validation Module**: `services/api-backend/utils/input-validation.js`
- **User Profile Service**: `services/api-backend/services/user-profile-service.js`
- **User Profile Routes**: `services/api-backend/routes/user-profile.js`
- **Tests**: `test/api-backend/input-validation.test.js`
- **Documentation**: `services/api-backend/INPUT_VALIDATION_IMPLEMENTATION.md`

## Quick Start

### Import Validation Functions

```javascript
import {
  validateAndSanitizeProfile,
  validateAndSanitizePreferences,
  validateName,
  validateEmail,
  validateUrl,
  logValidationError,
} from '../utils/input-validation.js';
```

### Validate Profile Data

```javascript
const validation = validateAndSanitizeProfile(req.body.profile);
if (!validation.valid) {
  return res.status(400).json({
    error: 'Validation error',
    message: validation.error,
  });
}

// Use sanitized data
const sanitizedProfile = validation.data;
```

### Validate Preferences

```javascript
const validation = validateAndSanitizePreferences(req.body.preferences);
if (!validation.valid) {
  return res.status(400).json({
    error: 'Validation error',
    message: validation.error,
  });
}

// Use sanitized data
const sanitizedPreferences = validation.data;
```

### Validate Individual Fields

```javascript
// Validate name
const nameValidation = validateName('John');
if (!nameValidation.valid) {
  throw new Error(nameValidation.error);
}

// Validate email
const emailValidation = validateEmail('user@example.com');
if (!emailValidation.valid) {
  throw new Error(emailValidation.error);
}

// Validate URL
const urlValidation = validateUrl('https://example.com/avatar.jpg');
if (!urlValidation.valid) {
  throw new Error(urlValidation.error);
}
```

## Validation Functions

### String Validation

- `sanitizeString(input)` - Escapes HTML special characters
- `isValidLength(input, min, max)` - Validates string length
- `isNotEmpty(input)` - Validates non-empty string
- `isAlphanumericUnderscore(input)` - Validates alphanumeric + underscore
- `isSlugFormat(input)` - Validates slug format

### Type Validation

- `isValidBoolean(input)` - Validates boolean type
- `isValidNumber(input, min, max)` - Validates number
- `isValidInteger(input, min, max)` - Validates integer
- `isOneOf(input, allowedValues)` - Validates enum value

### Format Validation

- `isValidEmail(email)` - Validates email format
- `isValidUrl(url)` - Validates URL format

### Domain-Specific Validation

- `validateName(name, maxLength)` - Validates user names
- `validateEmail(email)` - Validates email addresses
- `validateUrl(url, allowEmpty)` - Validates URLs
- `validateTheme(theme)` - Validates theme (light/dark)
- `validateLanguage(language, maxLength)` - Validates language codes
- `validateNotifications(notifications)` - Validates notification preference
- `validatePreferences(preferences)` - Validates preferences object
- `validateProfile(profile)` - Validates profile object

### Composite Validation

- `validateAndSanitizeProfile(profileData)` - Validates and sanitizes profile
- `validateAndSanitizePreferences(preferences)` - Validates and sanitizes preferences

## Security Features

### XSS Prevention

- HTML special characters are escaped: `<`, `>`, `"`, `'`, `/`, `&`
- Null bytes are removed
- Input validation rejects malicious patterns

### SQL Injection Prevention

- All database queries use parameterized queries
- User input is never concatenated into SQL strings
- PostgreSQL driver handles escaping

### Input Validation

- Type checking for all inputs
- Length validation for strings
- Format validation for emails and URLs
- Enum validation for preferences

## Error Handling

### Validation Error Format

```javascript
{
  valid: false,
  error: "Error message describing what's wrong"
}
```

### Logging Validation Errors

```javascript
import { logValidationError } from '../utils/input-validation.js';

logValidationError(
  'PUT /api/users/profile',  // endpoint
  userId,                     // user ID
  'profile',                  // field
  'Invalid profile data',     // reason
  { additionalContext: 'value' }  // optional context
);
```

## Testing

Run validation tests:

```bash
npm test -- --testNamePattern="Input Validation Utilities"
```

Run user profile tests:

```bash
npm test -- --testNamePattern="UserProfileService"
```

Run all tests:

```bash
npm test
```

## Common Patterns

### Validate and Update Profile

```javascript
// In route handler
const validation = validateAndSanitizeProfile(req.body.profile);
if (!validation.valid) {
  logValidationError('PUT /api/users/profile', userId, 'profile', validation.error);
  return res.status(400).json({
    error: 'Validation error',
    message: validation.error,
  });
}

// In service
const updatedProfile = await userProfileService.updateUserProfile(userId, {
  profile: validation.data,
});
```

### Validate and Update Preferences

```javascript
// In route handler
const validation = validateAndSanitizePreferences(req.body);
if (!validation.valid) {
  logValidationError('PUT /api/users/preferences', userId, 'preferences', validation.error);
  return res.status(400).json({
    error: 'Validation error',
    message: validation.error,
  });
}

// In service
const updatedPreferences = await userProfileService.updateUserPreferences(
  userId,
  validation.data,
);
```

## Requirements Coverage

✅ **Requirement 3.7: Input Validation and Injection Prevention**

- Comprehensive input validation for all user endpoints
- SQL injection prevention via parameterized queries
- XSS prevention through input sanitization

## Performance

- Lightweight validation functions
- Optimized regex patterns
- No external dependencies
- Fast execution time

## Future Enhancements

- Rate limiting on validation failures
- Machine learning for anomaly detection
- Content Security Policy headers
- Input whitelisting per field

## References

- OWASP Input Validation Cheat Sheet
- OWASP SQL Injection Prevention
- OWASP XSS Prevention Cheat Sheet
- PostgreSQL Parameterized Queries
- Node.js URL API
