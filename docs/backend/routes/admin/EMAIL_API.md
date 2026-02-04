# Email Configuration API Reference

## Overview

The Email Configuration API provides secure administrative endpoints for managing email services, Google Workspace integration, and email delivery tracking.

## Authentication

All endpoints require:

- Valid JWT token in `Authorization: Bearer <token>` header
- Admin role with appropriate permissions
- Permissions: `view_email_config` (read), `manage_email_config` (write)

## Endpoints

### 1. Start Google Workspace OAuth Flow

**Endpoint:** `POST /api/admin/email/oauth/start`

**Permissions Required:** `manage_email_config`

**Description:** Initiates Google Workspace OAuth 2.0 authentication flow.

**Request:**

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/oauth/start" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "authorizationUrl": "https://accounts.google.com/o/oauth2/v2/auth?...",
    "state": "random_state_string_for_csrf_protection"
  },
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `500` - Failed to start OAuth flow

---

### 2. Handle Google OAuth Callback

**Endpoint:** `POST /api/admin/email/oauth/callback`

**Permissions Required:** `manage_email_config`

**Description:** Processes Google OAuth callback and stores encrypted credentials.

**Request Body:**

```json
{
  "code": "authorization_code_from_google",
  "state": "state_string_from_oauth_start"
}
```

**Request:**

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/oauth/callback" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "4/0AY0e-g...",
    "state": "random_state_string"
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "configuration": {
      "id": "config-uuid",
      "provider": "google_workspace",
      "from_address": "noreply@zoidbot.online",
      "is_active": true,
      "created_at": "2025-01-16T10:30:00.000Z"
    },
    "userEmail": "noreply@zoidbot.online"
  },
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `400` - Missing code or state parameter
- `400` - Invalid or expired state parameter
- `403` - State mismatch (possible CSRF attempt)
- `500` - Failed to process OAuth callback

---

### 3. Get Email Configuration

**Endpoint:** `GET /api/admin/email/config`

**Permissions Required:** `view_email_config`

**Description:** Retrieves current email configuration(s) without sensitive data.

**Request:**

```bash
curl -X GET "https://api.zoidbot.online/api/admin/email/config" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "configurations": [
      {
        "id": "config-uuid",
        "provider": "google_workspace",
        "from_address": "noreply@zoidbot.online",
        "from_name": "Zoidbot",
        "reply_to_address": "support@zoidbot.online",
        "is_active": true,
        "created_at": "2025-01-16T10:30:00.000Z",
        "updated_at": "2025-01-16T10:30:00.000Z"
      }
    ]
  },
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `500` - Failed to retrieve configuration

---

### 4. Delete Email Configuration

**Endpoint:** `DELETE /api/admin/email/config`

**Permissions Required:** `manage_email_config`

**Query Parameters:**

- `provider` (optional): Email provider to delete (default: `google_workspace`)
  - Valid values: `google_workspace`, `smtp_relay`, `sendgrid`

**Description:** Deletes email configuration for specified provider.

**Request:**

```bash
curl -X DELETE "https://api.zoidbot.online/api/admin/email/config?provider=google_workspace" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**

```json
{
  "success": true,
  "message": "google_workspace configuration deleted successfully",
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `400` - Invalid provider
- `500` - Failed to delete configuration

---

### 5. Send Test Email

**Endpoint:** `POST /api/admin/email/test`

**Permissions Required:** `manage_email_config`

**Description:** Sends a test email to verify configuration is working.

**Request Body:**

```json
{
  "recipientEmail": "test@example.com",
  "subject": "Test Email from Zoidbot"
}
```

**Request:**

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/test" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "recipientEmail": "test@example.com",
    "subject": "Test Email"
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "messageId": "gmail-message-id",
    "recipientEmail": "test@example.com",
    "subject": "Test Email from Zoidbot",
    "sentAt": "2025-01-16T10:30:00.000Z"
  },
  "message": "Test email sent successfully",
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `400` - Missing recipientEmail parameter
- `400` - Invalid email format
- `400` - No Google Workspace configuration found
- `500` - Failed to send test email

---

### 6. Get Email Service Status

**Endpoint:** `GET /api/admin/email/status`

**Permissions Required:** `view_email_config`

**Description:** Retrieves current email service status and configuration.

**Request:**

```bash
curl -X GET "https://api.zoidbot.online/api/admin/email/status" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "status": {
      "configured": true,
      "provider": "google_workspace",
      "from_address": "noreply@zoidbot.online",
      "is_active": true,
      "created_at": "2025-01-16T10:30:00.000Z",
      "updated_at": "2025-01-16T10:30:00.000Z"
    }
  },
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `500` - Failed to retrieve status

---

### 7. Get Google Workspace Quota Usage

**Endpoint:** `GET /api/admin/email/quota`

**Permissions Required:** `view_email_config`

**Description:** Retrieves Gmail quota information and message counts.

**Request:**

```bash
curl -X GET "https://api.zoidbot.online/api/admin/email/quota" \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "quota": {
      "messagesTotal": 1234,
      "messagesUnread": 45,
      "emailAddress": "noreply@zoidbot.online",
      "historyId": "12345",
      "retrievedAt": "2025-01-16T10:30:00.000Z"
    }
  },
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error Responses:**

- `400` - No Google Workspace configuration found
- `500` - Failed to retrieve quota

---

## Audit Logging

All email configuration changes are automatically logged to the audit trail with:

- Admin user ID and role
- Action type (e.g., `email_oauth_configured`, `test_email_sent`)
- Resource type and ID
- IP address and user agent
- Timestamp and additional context

## Security Features

1. **OAuth State Validation:** CSRF protection using state parameter with 10-minute expiry
2. **Credential Encryption:** All tokens encrypted with AES-256-GCM
3. **Permission Checking:** Role-based access control for all operations
4. **Audit Logging:** Comprehensive logging of all configuration changes
5. **Rate Limiting:** Admin-specific rate limits applied to all endpoints

## Error Handling

All endpoints follow consistent error response format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```

Common error codes:

- `NO_TOKEN` - No JWT token provided
- `INVALID_TOKEN` - Invalid or expired JWT token
- `INSUFFICIENT_PERMISSIONS` - User lacks required permissions
- `MISSING_PARAMS` - Required parameters missing
- `INVALID_EMAIL` - Invalid email format
- `NO_CONFIG` - No email configuration found
- `OAUTH_START_FAILED` - Failed to start OAuth flow
- `OAUTH_CALLBACK_FAILED` - Failed to process OAuth callback
- `CONFIG_RETRIEVAL_FAILED` - Failed to retrieve configuration
- `CONFIG_DELETE_FAILED` - Failed to delete configuration
- `TEST_EMAIL_FAILED` - Failed to send test email
- `STATUS_RETRIEVAL_FAILED` - Failed to retrieve status
- `QUOTA_RETRIEVAL_FAILED` - Failed to retrieve quota

## Rate Limiting

- **Read Operations:** 200 requests/minute (adminReadOnlyLimiter)
- **Write Operations:** 100 requests/minute (adminWriteLimiter)

## Examples

### Complete OAuth Setup Flow

1. Start OAuth flow:

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/oauth/start" \
  -H "Authorization: Bearer <jwt_token>"
```

1. User visits the returned `authorizationUrl` and grants permissions

2. Handle callback:

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/oauth/callback" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "<code_from_google>",
    "state": "<state_from_step_1>"
  }'
```

1. Verify configuration:

```bash
curl -X GET "https://api.zoidbot.online/api/admin/email/status" \
  -H "Authorization: Bearer <jwt_token>"
```

1. Send test email:

```bash
curl -X POST "https://api.zoidbot.online/api/admin/email/test" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "recipientEmail": "admin@example.com"
  }'
```

## Related Documentation

- [Email Relay & DNS Setup Requirements](../../../.kiro/specs/email-relay-dns-setup/requirements.md)
- [Email Relay & DNS Setup Design](../../../.kiro/specs/email-relay-dns-setup/design.md)
- [Google Workspace Service](../../services/GOOGLE_WORKSPACE_SERVICE_README.md)
- [Email Config Service](../../services/email-config-service.js)
- [Admin API Reference](../../../docs/API/ADMIN_API.md)
