# User Profile API Quick Reference

## Endpoints Overview

All endpoints require JWT authentication via `Authorization: Bearer <token>` header.

## 1. Get User Profile

**Endpoint:** `GET /api/users/profile`

**Authentication:** Required (JWT)

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user-uuid-1",
    "auth0Id": "auth0|123456",
    "email": "user@example.com",
    "profile": {
      "firstName": "John",
      "lastName": "Doe",
      "nickname": "johndoe",
      "avatar": "https://example.com/avatar.jpg",
      "preferences": {
        "theme": "dark",
        "language": "en",
        "notifications": true
      }
    },
    "emailVerified": true,
    "locale": "en",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-15T10:30:00Z",
    "lastLogin": "2024-01-15T10:30:00Z",
    "loginCount": 5,
    "metadata": {}
  },
  "timestamp": "2024-01-15T10:35:00Z"
}
```

## 2. Update User Profile

**Endpoint:** `PUT /api/users/profile`

**Authentication:** Required (JWT)

**Request Body:**
```json
{
  "profile": {
    "firstName": "Jane",
    "lastName": "Smith",
    "nickname": "janesmith",
    "avatar": "https://example.com/new-avatar.jpg",
    "preferences": {
      "theme": "light",
      "language": "es",
      "notifications": false
    }
  }
}
```

**Response:** Same as Get User Profile

**Validation Rules:**
- firstName: max 100 characters
- lastName: max 100 characters
- nickname: max 100 characters
- avatar: valid URL format
- theme: "light" or "dark"
- language: max 10 characters
- notifications: boolean

## 3. Get User Preferences

**Endpoint:** `GET /api/users/preferences`

**Authentication:** Required (JWT)

**Response:**
```json
{
  "success": true,
  "data": {
    "theme": "dark",
    "language": "en",
    "notifications": true
  },
  "timestamp": "2024-01-15T10:35:00Z"
}
```

**Default Preferences:**
```json
{
  "theme": "light",
  "language": "en",
  "notifications": true
}
```

## 4. Update User Preferences

**Endpoint:** `PUT /api/users/preferences`

**Authentication:** Required (JWT)

**Request Body:**
```json
{
  "theme": "dark",
  "language": "fr",
  "notifications": false
}
```

**Response:** Same as Get User Preferences

**Validation Rules:**
- theme: "light" or "dark"
- language: max 10 characters
- notifications: boolean

**Partial Updates:** You can update individual preferences:
```json
{
  "theme": "dark"
}
```

## 5. Update User Avatar

**Endpoint:** `PUT /api/users/avatar`

**Authentication:** Required (JWT)

**Request Body:**
```json
{
  "avatarUrl": "https://example.com/new-avatar.jpg"
}
```

**Response:** Same as Get User Profile

**Validation Rules:**
- avatarUrl: required, must be valid URL format

## Error Responses

### 400 Bad Request
```json
{
  "error": "Validation error",
  "code": "VALIDATION_ERROR",
  "message": "Invalid theme. Must be \"light\" or \"dark\""
}
```

### 401 Unauthorized
```json
{
  "error": "Authentication required",
  "code": "AUTH_REQUIRED",
  "message": "Please authenticate to access profile information"
}
```

### 404 Not Found
```json
{
  "error": "User not found",
  "code": "USER_NOT_FOUND",
  "message": "User profile not found"
}
```

### 503 Service Unavailable
```json
{
  "error": "Service unavailable",
  "code": "SERVICE_UNAVAILABLE",
  "message": "User profile service is not initialized"
}
```

## Usage Examples

### JavaScript/TypeScript

```javascript
// Get user profile
const response = await fetch('/api/users/profile', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
const profile = await response.json();

// Update preferences
const updateResponse = await fetch('/api/users/preferences', {
  method: 'PUT',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    theme: 'dark',
    language: 'en',
    notifications: true
  })
});
const updatedPrefs = await updateResponse.json();

// Update avatar
const avatarResponse = await fetch('/api/users/avatar', {
  method: 'PUT',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    avatarUrl: 'https://example.com/avatar.jpg'
  })
});
const updatedProfile = await avatarResponse.json();
```

### cURL

```bash
# Get profile
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/api/users/profile

# Update preferences
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"theme":"dark","language":"en","notifications":true}' \
  https://api.cloudtolocalllm.online/api/users/preferences

# Update avatar
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"avatarUrl":"https://example.com/avatar.jpg"}' \
  https://api.cloudtolocalllm.online/api/users/avatar
```

## Rate Limiting

All endpoints are subject to standard rate limiting:
- **Default:** 100 requests/minute per user
- **Tier-based:** Premium and Enterprise tiers may have higher limits

Rate limit information is included in response headers:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## Notes

1. All timestamps are in ISO 8601 format (UTC)
2. User ID is extracted from JWT token (sub claim)
3. Profile updates are atomic (all or nothing)
4. Preferences are merged with existing preferences on update
5. Avatar URL must be publicly accessible
6. All endpoints return 200 on success (except errors)

## Related Endpoints

- **Authentication:** `/api/auth/*` - Token management
- **User Tier:** `/api/users/tier` - Tier information
- **Admin Users:** `/api/admin/users` - Admin user management
