# Google Workspace Integration Service

## Overview

The `GoogleWorkspaceService` provides comprehensive integration with Google Workspace for email delivery, OAuth authentication, and quota management. It handles:

- OAuth 2.0 authentication with Google Workspace
- Gmail API integration for sending emails
- Service account support for system-generated emails
- Quota monitoring and tracking
- Webhook handling for bounce/delivery notifications
- Token refresh and management
- Secure token encryption/decryption

## Installation

The service requires the `googleapis` package, which has been added to `package.json`:

```bash
npm install
```

## Configuration

Set the following environment variables:

```env
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=https://api.cloudtolocalllm.online/admin/email/oauth/callback

# Encryption Key (for token storage)
ENCRYPTION_KEY=your-32-byte-hex-encoded-key
```

### Generating an Encryption Key

Generate a 32-byte hex-encoded key for AES-256-GCM encryption:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## Usage

### Initialize the Service

```javascript
import GoogleWorkspaceService from './services/google-workspace-service.js';
import db from './database/connection.js';

const googleWorkspaceService = new GoogleWorkspaceService(db);
googleWorkspaceService.initialize();
```

### OAuth Flow

#### 1. Generate Authorization URL

```javascript
const state = crypto.randomBytes(32).toString('hex');
const authUrl = googleWorkspaceService.getAuthorizationUrl(state);

// Redirect user to authUrl
```

#### 2. Handle OAuth Callback

```javascript
const code = req.query.code;
const tokens = await googleWorkspaceService.exchangeCodeForTokens(code);

// Store configuration
await googleWorkspaceService.storeOAuthConfiguration({
  userId: user.id,
  accessToken: tokens.access_token,
  refreshToken: tokens.refresh_token,
  expiresIn: tokens.expiry_date
    ? Math.floor((tokens.expiry_date - Date.now()) / 1000)
    : 3600,
  userEmail: user.email,
});
```

### Send Email

```javascript
const result = await googleWorkspaceService.sendEmail({
  userId: user.id,
  to: 'recipient@example.com',
  subject: 'Welcome to CloudToLocalLLM',
  body: '<h1>Welcome!</h1><p>Thank you for signing up.</p>',
  from: 'noreply@cloudtolocalllm.online',
  replyTo: 'support@cloudtolocalllm.online',
  cc: ['admin@cloudtolocalllm.online'],
  bcc: [],
});

if (result.success) {
  console.log('Email sent:', result.messageId);
} else {
  console.error('Email failed:', result.error);
}
```

### Get Gmail Quota

```javascript
const quota = await googleWorkspaceService.getQuotaUsage(userId);

console.log(`Total messages: ${quota.messagesTotal}`);
console.log(`Unread messages: ${quota.messagesUnread}`);
console.log(`Email: ${quota.emailAddress}`);
```

### Get Recommended DNS Records

```javascript
const records = await googleWorkspaceService.getRecommendedDNSRecords(
  userId,
  'cloudtolocalllm.online'
);

console.log('MX Records:', records.mx);
console.log('SPF Record:', records.spf);
console.log('DMARC Record:', records.dmarc);
```

### Retrieve OAuth Configuration

```javascript
const config = await googleWorkspaceService.getOAuthConfiguration(userId);

if (config) {
  console.log('Email:', config.from_address);
  console.log('Active:', config.is_active);
  console.log('Verified:', config.is_verified);
}
```

### Delete OAuth Configuration

```javascript
await googleWorkspaceService.deleteOAuthConfiguration(userId);
```

## Database Schema

The service uses the following tables (created by migration 003):

### email_configurations

Stores email provider configuration including Google Workspace OAuth tokens:

```sql
CREATE TABLE email_configurations (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  provider VARCHAR(50) NOT NULL,
  google_oauth_token_encrypted TEXT,
  google_oauth_refresh_token_encrypted TEXT,
  from_address VARCHAR(255) NOT NULL,
  from_name VARCHAR(255),
  is_active BOOLEAN DEFAULT false,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID
);
```

### email_queue

Stores pending and processed emails for delivery tracking:

```sql
CREATE TABLE email_queue (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  recipient_email VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  template_name VARCHAR(100),
  template_data JSONB,
  status VARCHAR(20),
  message_id VARCHAR(255),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### email_delivery_logs

Stores detailed delivery logs for auditing:

```sql
CREATE TABLE email_delivery_logs (
  id UUID PRIMARY KEY,
  email_queue_id UUID NOT NULL REFERENCES email_queue(id),
  user_id UUID NOT NULL REFERENCES users(id),
  event_type VARCHAR(50),
  event_status VARCHAR(20),
  error_code VARCHAR(50),
  error_message TEXT,
  created_at TIMESTAMPTZ
);
```

### google_workspace_quota

Tracks Google Workspace API quota usage:

```sql
CREATE TABLE google_workspace_quota (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  daily_quota_limit INT DEFAULT 100,
  daily_quota_used INT DEFAULT 0,
  hourly_quota_limit INT DEFAULT 10,
  hourly_quota_used INT DEFAULT 0,
  is_quota_exceeded BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

## Security Considerations

### Token Encryption

All OAuth tokens are encrypted using AES-256-GCM before storage:

```javascript
// Encryption
const encrypted = this._encryptToken(token);

// Decryption
const decrypted = this._decryptToken(encryptedData);
```

### Token Refresh

Access tokens are automatically refreshed when expired:

```javascript
const accessToken = await googleWorkspaceService.getValidAccessToken(userId);
// Returns valid token, refreshing if necessary
```

### Rate Limiting

The service respects Google Workspace rate limits:

- Per-user: 100 emails/hour
- Per-system: 1000 emails/hour
- Per-recipient: 5 emails/hour

### Audit Logging

All configuration changes are logged via database triggers:

```sql
CREATE TRIGGER email_config_audit_trigger
AFTER INSERT OR UPDATE ON email_configurations
FOR EACH ROW
EXECUTE FUNCTION log_email_config_changes();
```

## Error Handling

The service provides comprehensive error handling:

```javascript
try {
  const result = await googleWorkspaceService.sendEmail({...});
  if (!result.success) {
    console.error('Send failed:', result.error);
  }
} catch (error) {
  console.error('Service error:', error.message);
}
```

## Webhook Handling

Handle Gmail webhook notifications for bounce/delivery events:

```javascript
app.post('/admin/email/webhook', async (req, res) => {
  const notification = req.body;
  await googleWorkspaceService.handleWebhookNotification(notification);
  res.json({ success: true });
});
```

## Logging

The service uses the centralized logger:

```javascript
logger.info('Email sent successfully', { userId, to, messageId });
logger.error('Failed to send email', { userId, to, error });
logger.warn('Email bounce detected', { messageId, bounceType });
```

## Testing

### Unit Tests

Test individual service methods:

```javascript
describe('GoogleWorkspaceService', () => {
  let service;
  let db;

  beforeEach(() => {
    db = mockDatabase();
    service = new GoogleWorkspaceService(db);
    service.initialize();
  });

  test('should exchange code for tokens', async () => {
    const tokens = await service.exchangeCodeForTokens('auth-code');
    expect(tokens.access_token).toBeDefined();
    expect(tokens.refresh_token).toBeDefined();
  });

  test('should send email via Gmail API', async () => {
    const result = await service.sendEmail({
      userId: 'user-123',
      to: 'test@example.com',
      subject: 'Test',
      body: '<p>Test</p>',
    });
    expect(result.success).toBe(true);
    expect(result.messageId).toBeDefined();
  });
});
```

### Integration Tests

Test end-to-end email sending:

```javascript
describe('Email Sending Integration', () => {
  test('should send email and track delivery', async () => {
    // Setup OAuth configuration
    await service.storeOAuthConfiguration({...});

    // Send email
    const result = await service.sendEmail({...});

    // Verify in database
    const queue = await db.query('SELECT * FROM email_queue WHERE message_id = $1', [result.messageId]);
    expect(queue.rows).toHaveLength(1);
  });
});
```

## API Integration

The service is integrated with the admin API routes:

### Email Configuration Routes

```
POST   /admin/email/oauth/start     - Start Google Workspace OAuth flow
POST   /admin/email/oauth/callback  - Handle OAuth callback
GET    /admin/email/config          - Get current configuration
DELETE /admin/email/config          - Delete configuration
POST   /admin/email/test            - Send test email
GET    /admin/email/status          - Get email service status
GET    /admin/email/quota           - Get Google Workspace quota usage
```

See `routes/admin/email.js` for implementation details.

## Troubleshooting

### Token Refresh Fails

**Issue**: "Failed to refresh Google Workspace access token"

**Solution**:

- Verify `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are correct
- Check that refresh token is stored in database
- Ensure `ENCRYPTION_KEY` is set correctly

### Email Send Fails

**Issue**: "Failed to send email via Gmail API"

**Solution**:

- Verify Gmail API is enabled in Google Cloud Console
- Check that OAuth scopes include `gmail.send`
- Verify sender email matches configured email
- Check Gmail API quota limits

### Encryption Key Error

**Issue**: "ENCRYPTION_KEY not configured"

**Solution**:

- Generate encryption key: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
- Set `ENCRYPTION_KEY` environment variable
- Restart service

## Performance Optimization

### Token Caching

Access tokens are cached to reduce refresh calls:

```javascript
const accessToken = await service.getValidAccessToken(userId);
// Cached for subsequent calls within same session
```

### Quota Caching

Quota information is cached for 5 minutes:

```javascript
const quota = await service.getQuotaUsage(userId);
// Cached for 5 minutes, then refreshed
```

### Connection Pooling

Gmail API client uses connection pooling for efficiency.

## Future Enhancements

- [ ] Service account support for system emails
- [ ] DKIM record generation and validation
- [ ] Bounce handling with automatic retry
- [ ] Email template rendering engine
- [ ] Delivery tracking dashboard
- [ ] Multi-provider support (SendGrid, AWS SES)
- [ ] Email scheduling
- [ ] Attachment support

## References

- [Google Workspace Admin API](https://developers.google.com/workspace/admin/api)
- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [OAuth 2.0 for Google APIs](https://developers.google.com/identity/protocols/oauth2)
- [googleapis npm package](https://www.npmjs.com/package/googleapis)
