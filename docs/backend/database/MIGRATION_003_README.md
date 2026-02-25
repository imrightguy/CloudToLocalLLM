# Migration 003: Email Relay & DNS Configuration Schema

## Overview

This migration creates the database schema for the email relay service and DNS configuration management system. It includes tables for:

- Email provider configurations (Google Workspace OAuth, SMTP relay)
- DNS records management (Cloudflare integration)
- Email queue and delivery tracking
- Google Workspace quota monitoring
- Email templates
- Audit logging for configuration changes

## Tables Created

### 1. `email_configurations`

Stores email provider configuration including Google Workspace OAuth tokens and SMTP relay credentials.

**Key Columns:**

- `id` - UUID primary key
- `user_id` - Reference to users table
- `provider` - Email provider type (google_workspace, smtp_relay, sendgrid)
- `google_oauth_token_encrypted` - Encrypted OAuth access token
- `google_oauth_refresh_token_encrypted` - Encrypted refresh token
- `google_service_account_encrypted` - Encrypted service account JSON
- `smtp_host`, `smtp_port`, `smtp_username`, `smtp_password_encrypted` - SMTP relay config
- `from_address`, `from_name`, `reply_to_address` - Email sender info
- `is_active`, `is_verified` - Configuration status
- `created_at`, `updated_at` - Timestamps
- `created_by`, `updated_by` - Audit references

**Indexes:**

- `idx_email_configurations_user_id` - For user lookups
- `idx_email_configurations_provider` - For provider filtering
- `idx_email_configurations_is_active` - For active config queries
- `idx_email_configurations_is_verified` - For verification status
- `idx_email_configurations_created_at` - For time-based queries

### 2. `dns_records`

Stores DNS records managed via Cloudflare or other DNS providers.

**Key Columns:**

- `id` - UUID primary key
- `user_id` - Reference to users table
- `provider` - DNS provider (cloudflare, route53, azure_dns)
- `provider_record_id` - ID from DNS provider
- `record_type` - DNS record type (A, AAAA, CNAME, MX, TXT, SPF, DKIM, DMARC)
- `name` - Full domain name
- `value` - Record value
- `ttl` - Time to live
- `priority` - For MX records
- `status` - Record status (pending, active, failed, invalid)
- `validation_status` - Validation result
- `created_at`, `updated_at` - Timestamps

**Indexes:**

- `idx_dns_records_user_id` - For user lookups
- `idx_dns_records_provider` - For provider filtering
- `idx_dns_records_record_type` - For record type queries
- `idx_dns_records_name` - For domain name lookups
- `idx_dns_records_status` - For status filtering
- `idx_dns_records_created_at` - For time-based queries

### 3. `email_queue`

Stores pending and processed emails for delivery tracking.

**Key Columns:**

- `id` - UUID primary key
- `user_id` - Reference to users table
- `recipient_email`, `recipient_name` - Email recipient info
- `subject` - Email subject
- `template_name`, `template_data` - Template information
- `html_body`, `text_body` - Email content
- `status` - Delivery status (pending, queued, sending, sent, failed, bounced, spam)
- `retry_count`, `max_retries` - Retry tracking
- `message_id` - Provider's message ID
- `sent_at`, `delivered_at`, `bounced_at` - Delivery timestamps
- `bounce_type`, `bounce_reason` - Bounce information
- `created_at`, `updated_at` - Timestamps

**Indexes:**

- `idx_email_queue_user_id` - For user lookups
- `idx_email_queue_status` - For status filtering
- `idx_email_queue_recipient_email` - For recipient lookups
- `idx_email_queue_created_at` - For time-based queries
- `idx_email_queue_sent_at` - For sent email queries
- `idx_email_queue_status_created` - Composite index for status + time queries

### 4. `email_delivery_logs`

Stores detailed delivery logs for auditing and troubleshooting.

**Key Columns:**

- `id` - UUID primary key
- `email_queue_id` - Reference to email_queue
- `user_id` - Reference to users table
- `event_type` - Event type (queued, sending, sent, failed, bounced, opened, clicked, complained)
- `event_status` - Event status
- `error_code`, `error_message` - Error information
- `provider` - Email provider
- `provider_event_id` - Provider's event ID
- `created_at` - Timestamp

**Indexes:**

- `idx_email_delivery_logs_email_queue_id` - For email lookups
- `idx_email_delivery_logs_user_id` - For user lookups
- `idx_email_delivery_logs_event_type` - For event type filtering
- `idx_email_delivery_logs_created_at` - For time-based queries

### 5. `google_workspace_quota`

Tracks Google Workspace API quota usage and limits.

**Key Columns:**

- `id` - UUID primary key
- `user_id` - Reference to users table
- `daily_quota_limit`, `daily_quota_used` - Daily quota tracking
- `daily_quota_reset_at` - When daily quota resets
- `hourly_quota_limit`, `hourly_quota_used` - Hourly quota tracking
- `hourly_quota_reset_at` - When hourly quota resets
- `is_quota_exceeded` - Quota status
- `quota_exceeded_at` - When quota was exceeded
- `created_at`, `updated_at` - Timestamps

**Indexes:**

- `idx_google_workspace_quota_user_id` - For user lookups
- `idx_google_workspace_quota_is_quota_exceeded` - For quota status queries
- `idx_google_workspace_quota_updated_at` - For time-based queries

### 6. `email_templates`

Stores email templates for different notification types.

**Key Columns:**

- `id` - UUID primary key
- `user_id` - Reference to users table (NULL for system templates)
- `name` - Template name
- `description` - Template description
- `subject` - Email subject template
- `html_body`, `text_body` - Email body templates
- `variables` - Array of variable names used in template
- `is_active` - Template status
- `is_system_template` - Whether it's a system template
- `created_at`, `updated_at` - Timestamps
- `created_by`, `updated_by` - Audit references

**Indexes:**

- `idx_email_templates_user_id` - For user lookups
- `idx_email_templates_name` - For template name lookups
- `idx_email_templates_is_active` - For active template queries
- `idx_email_templates_is_system_template` - For system template queries

## Triggers and Functions

### 1. `log_email_config_changes()`

Logs email configuration changes to the audit_logs table.

### 2. `log_dns_record_changes()`

Logs DNS record changes to the audit_logs table.

### 3. `update_updated_at_column()`

Generic function to automatically update the `updated_at` timestamp on record modifications.

**Triggers using this function:**

- `email_configurations_updated_at_trigger`
- `dns_records_updated_at_trigger`
- `email_queue_updated_at_trigger`
- `google_workspace_quota_updated_at_trigger`
- `email_templates_updated_at_trigger`

## Requirements Covered

This migration addresses the following requirements:

- **1.1**: Google Workspace Integration - OAuth token storage and configuration
- **1.2**: Email Relay Container - Email queue and delivery tracking
- **1.3**: DNS Configuration Management - DNS records table and Cloudflare integration

## Usage

### Apply Migration

```bash
cd services/api-backend
node database/migrations/run-migration.js up 003
```

### Rollback Migration

```bash
cd services/api-backend
node database/migrations/run-migration.js down 003
```

### Check Migration Status

```bash
cd services/api-backend
node database/migrations/run-migration.js status
```

## Data Encryption

The migration includes encrypted fields for sensitive data:

- `google_oauth_token_encrypted` - Google OAuth access token
- `google_oauth_refresh_token_encrypted` - Google OAuth refresh token
- `google_service_account_encrypted` - Google service account JSON
- `smtp_password_encrypted` - SMTP relay password

These fields should be encrypted using AES-256-GCM before storage and decrypted when retrieved.

## Performance Considerations

All tables include strategic indexes on:

- Foreign keys (user_id)
- Status columns for filtering
- Timestamp columns for time-range queries
- Composite indexes for common query patterns

The `email_queue` table includes a composite index on `(status, created_at)` for efficient queue processing queries.

## Audit Logging

Configuration changes are automatically logged to the `audit_logs` table via triggers:

- Email configuration changes (create/update)
- DNS record changes (create/update/delete)

All changes include:

- User ID (who made the change)
- Action type (CREATE, UPDATE, DELETE)
- Resource type and ID
- Changed fields (provider, status, etc.)
- Timestamp

## Next Steps

After applying this migration:

1. Implement the Google Workspace Integration Service
2. Implement the Cloudflare DNS Configuration Service
3. Implement the Email Configuration Service
4. Implement the Email Queue Service
5. Create API routes for email and DNS management
6. Connect Flutter UI to backend APIs

## Troubleshooting

### Migration fails with "relation already exists"

The migration may have been partially applied. Check the database state:

```sql
SELECT * FROM schema_migrations WHERE version = '003';
```

If the migration is marked as applied but tables don't exist, manually clean up:

```bash
node database/migrations/run-migration.js down 003
```

Then reapply:

```bash
node database/migrations/run-migration.js up 003
```

### Cannot connect to database

Ensure PostgreSQL is running and environment variables are set:

```bash
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=CloudToLocalLLM
export PGUSER=postgres
export PGPASSWORD=yourpassword
```

### Trigger function errors

If trigger functions fail to create, ensure the `audit_logs` table exists:

```sql
SELECT * FROM information_schema.tables WHERE table_name = 'audit_logs';
```

If it doesn't exist, run the main schema migration first:

```bash
node database/migrations/run-migration.js up 001
```

## References

- Requirements: `.kiro/specs/email-relay-dns-setup/requirements.md`
- Design: `.kiro/specs/email-relay-dns-setup/design.md`
- Tasks: `.kiro/specs/email-relay-dns-setup/tasks.md`
