# Email Configuration API - Quick Reference

## Endpoints Summary

| Method | Endpoint                          | Permission            | Purpose                 |
| ------ | --------------------------------- | --------------------- | ----------------------- |
| POST   | `/api/admin/email/oauth/start`    | `manage_email_config` | Start Google OAuth flow |
| POST   | `/api/admin/email/oauth/callback` | `manage_email_config` | Handle OAuth callback   |
| GET    | `/api/admin/email/config`         | `view_email_config`   | Get configuration       |
| DELETE | `/api/admin/email/config`         | `manage_email_config` | Delete configuration    |
| POST   | `/api/admin/email/test`           | `manage_email_config` | Send test email         |
| GET    | `/api/admin/email/status`         | `view_email_config`   | Get service status      |
| GET    | `/api/admin/email/quota`          | `view_email_config`   | Get Gmail quota         |

## Quick Start

### 1. Start OAuth Setup

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/email/oauth/start" \
  -H "Authorization: Bearer <token>"
```

### 2. Complete OAuth (after user grants permissions)

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/email/oauth/callback" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"code": "<code>", "state": "<state>"}'
```

### 3. Verify Configuration

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/email/status" \
  -H "Authorization: Bearer <token>"
```

### 4. Send Test Email

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/email/test" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"recipientEmail": "test@example.com"}'
```

## Response Format

All responses follow this format:

**Success (2xx):**

```json
{
  "success": true,
  "data": {
    /* endpoint-specific data */
  },
  "message": "Optional message",
  "timestamp": "2025-01-16T10:30:00.000Z"
}
```

**Error (4xx/5xx):**

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional details"
}
```

## Permissions

- **`view_email_config`** - Read email configuration, status, quota
- **`manage_email_config`** - Create, update, delete configuration; send test emails

## Rate Limits

- **Read:** 200 req/min
- **Write:** 100 req/min

## Common Error Codes

| Code                    | Status | Meaning                     |
| ----------------------- | ------ | --------------------------- |
| `MISSING_PARAMS`        | 400    | Required parameters missing |
| `INVALID_EMAIL`         | 400    | Invalid email format        |
| `INVALID_STATE`         | 400    | Invalid OAuth state         |
| `STATE_EXPIRED`         | 400    | OAuth state expired         |
| `STATE_MISMATCH`        | 403    | CSRF protection triggered   |
| `NO_CONFIG`             | 400    | No configuration found      |
| `OAUTH_CALLBACK_FAILED` | 500    | OAuth processing failed     |
| `TEST_EMAIL_FAILED`     | 500    | Test email send failed      |

## Implementation Notes

### OAuth Flow

1. State parameter is generated and stored with 10-minute expiry
2. State is validated on callback for CSRF protection
3. Tokens are encrypted with AES-256-GCM before storage
4. Refresh tokens are stored for automatic token refresh

### Credentials

- All sensitive data (tokens, passwords) are encrypted at rest
- Encryption key from `ENCRYPTION_KEY` environment variable
- Decryption happens only when needed for operations

### Audit Logging

All configuration changes are logged with:

- Admin user ID and role
- Action type
- IP address and user agent
- Timestamp

## Related Files

- Implementation: `services/api-backend/routes/admin/email.js`
- Services: `services/api-backend/services/google-workspace-service.js`
- Services: `services/api-backend/services/email-config-service.js`
- Full API Docs: `EMAIL_API.md`
