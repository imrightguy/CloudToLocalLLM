# DNS Configuration API Routes

## Overview

The DNS Configuration API provides secure administrative endpoints for managing DNS records via Cloudflare. All endpoints require admin authentication with appropriate permissions.

## Base Path

```
/api/admin/dns
```

## Authentication

All endpoints require:

- Valid JWT token with admin role
- Appropriate permission scope (`view_dns_config` or `manage_dns_config`)
- Rate limiting applied based on operation type

## Endpoints

### 1. Create DNS Record

**Endpoint:** `POST /api/admin/dns/records`

**Permission:** `manage_dns_config`

**Rate Limit:** Write limiter (50 req/min)

**Request Body:**

```json
{
  "recordType": "MX",
  "name": "mail.example.com",
  "value": "5 gmail-smtp-in.l.google.com",
  "ttl": 3600,
  "priority": 5
}
```

**Parameters:**

- `recordType` (required): DNS record type (A, AAAA, CNAME, MX, TXT, SPF, DKIM, DMARC, NS, SRV)
- `name` (required): Full domain name
- `value` (required): Record value
- `ttl` (optional): Time to live in seconds (60-86400, default: 3600)
- `priority` (optional): Priority for MX records

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "recordType": "MX",
    "name": "mail.example.com",
    "value": "5 gmail-smtp-in.l.google.com",
    "ttl": 3600,
    "priority": 5,
    "status": "active",
    "createdAt": "2024-01-15T10:30:00Z"
  },
  "message": "DNS record created successfully",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**

- `400 Bad Request`: Missing required fields or invalid record type
- `500 Internal Server Error`: Cloudflare API error

---

### 2. List DNS Records

**Endpoint:** `GET /api/admin/dns/records`

**Permission:** `view_dns_config`

**Rate Limit:** Read-only limiter (200 req/min)

**Query Parameters:**

- `recordType` (optional): Filter by record type
- `name` (optional): Filter by domain name

**Response:**

```json
{
  "success": true,
  "data": {
    "records": [
      {
        "id": "uuid",
        "recordType": "MX",
        "name": "mail.example.com",
        "value": "5 gmail-smtp-in.l.google.com",
        "ttl": 3600,
        "priority": 5,
        "status": "active",
        "validationStatus": "valid",
        "createdAt": "2024-01-15T10:30:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      }
    ]
  },
  "count": 1,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

### 3. Update DNS Record

**Endpoint:** `PUT /api/admin/dns/records/:id`

**Permission:** `manage_dns_config`

**Rate Limit:** Write limiter (50 req/min)

**URL Parameters:**

- `id` (required): Record ID

**Request Body:**

```json
{
  "value": "10 alt1.gmail-smtp-in.l.google.com",
  "ttl": 7200,
  "priority": 10
}
```

**Parameters:**

- `value` (optional): New record value
- `ttl` (optional): New TTL (60-86400)
- `priority` (optional): New priority for MX records

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "recordType": "MX",
    "name": "mail.example.com",
    "value": "10 alt1.gmail-smtp-in.l.google.com",
    "ttl": 7200,
    "priority": 10,
    "status": "active",
    "updatedAt": "2024-01-15T10:35:00Z"
  },
  "message": "DNS record updated successfully",
  "timestamp": "2024-01-15T10:35:00Z"
}
```

---

### 4. Delete DNS Record

**Endpoint:** `DELETE /api/admin/dns/records/:id`

**Permission:** `manage_dns_config`

**Rate Limit:** Write limiter (50 req/min)

**URL Parameters:**

- `id` (required): Record ID

**Response:**

```json
{
  "success": true,
  "message": "DNS record deleted successfully",
  "timestamp": "2024-01-15T10:40:00Z"
}
```

---

### 5. Validate DNS Records

**Endpoint:** `POST /api/admin/dns/validate`

**Permission:** `view_dns_config`

**Rate Limit:** Read-only limiter (200 req/min)

**Query Parameters:**

- `recordId` (optional): Validate specific record

**Response:**

```json
{
  "success": true,
  "data": {
    "valid": true,
    "records": [
      {
        "recordType": "MX",
        "valid": true
      },
      {
        "recordType": "SPF",
        "valid": true
      }
    ],
    "errors": []
  },
  "timestamp": "2024-01-15T10:45:00Z"
}
```

---

### 6. Get Google Workspace DNS Recommendations

**Endpoint:** `GET /api/admin/dns/google-records`

**Permission:** `view_dns_config`

**Rate Limit:** Read-only limiter (200 req/min)

**Query Parameters:**

- `domain` (optional): Domain name (defaults to configured domain)

**Response:**

```json
{
  "success": true,
  "data": {
    "domain": "cloudtolocalllm.online",
    "recommendations": {
      "mx": [
        {
          "type": "MX",
          "name": "cloudtolocalllm.online",
          "value": "5 gmail-smtp-in.l.google.com",
          "priority": 5,
          "ttl": 3600,
          "description": "Primary Google Workspace mail server"
        },
        {
          "type": "MX",
          "name": "cloudtolocalllm.online",
          "value": "10 alt1.gmail-smtp-in.l.google.com",
          "priority": 10,
          "ttl": 3600,
          "description": "Secondary Google Workspace mail server"
        },
        {
          "type": "MX",
          "name": "cloudtolocalllm.online",
          "value": "20 alt2.gmail-smtp-in.l.google.com",
          "priority": 20,
          "ttl": 3600,
          "description": "Tertiary Google Workspace mail server"
        }
      ],
      "spf": {
        "type": "TXT",
        "name": "cloudtolocalllm.online",
        "value": "v=spf1 include:_spf.google.com ~all",
        "ttl": 3600,
        "description": "SPF record for Google Workspace"
      },
      "dmarc": {
        "type": "TXT",
        "name": "_dmarc.cloudtolocalllm.online",
        "value": "v=DMARC1; p=quarantine; rua=mailto:postmaster@cloudtolocalllm.online",
        "ttl": 3600,
        "description": "DMARC policy record"
      }
    },
    "instructions": {
      "mx": "Add all three MX records with the specified priorities",
      "spf": "Add the SPF record to enable Google Workspace to send emails",
      "dmarc": "Add the DMARC record to enable email authentication"
    }
  },
  "timestamp": "2024-01-15T10:50:00Z"
}
```

---

### 7. One-Click Google Workspace Setup

**Endpoint:** `POST /api/admin/dns/setup-google`

**Permission:** `manage_dns_config`

**Rate Limit:** Write limiter (50 req/min)

**Request Body:**

```json
{
  "domain": "cloudtolocalllm.online",
  "recordTypes": ["mx", "spf", "dmarc"]
}
```

**Parameters:**

- `domain` (optional): Domain name (defaults to configured domain)
- `recordTypes` (optional): Array of record types to create (defaults to all)

**Response:**

```json
{
  "success": true,
  "data": {
    "domain": "cloudtolocalllm.online",
    "createdRecords": [
      {
        "id": "uuid",
        "recordType": "MX",
        "name": "cloudtolocalllm.online",
        "value": "5 gmail-smtp-in.l.google.com",
        "ttl": 3600,
        "priority": 5
      },
      {
        "id": "uuid",
        "recordType": "MX",
        "name": "cloudtolocalllm.online",
        "value": "10 alt1.gmail-smtp-in.l.google.com",
        "ttl": 3600,
        "priority": 10
      },
      {
        "id": "uuid",
        "recordType": "MX",
        "name": "cloudtolocalllm.online",
        "value": "20 alt2.gmail-smtp-in.l.google.com",
        "ttl": 3600,
        "priority": 20
      },
      {
        "id": "uuid",
        "recordType": "TXT",
        "name": "cloudtolocalllm.online",
        "value": "v=spf1 include:_spf.google.com ~all",
        "ttl": 3600
      },
      {
        "id": "uuid",
        "recordType": "TXT",
        "name": "_dmarc.cloudtolocalllm.online",
        "value": "v=DMARC1; p=quarantine; rua=mailto:postmaster@cloudtolocalllm.online",
        "ttl": 3600
      }
    ],
    "errors": []
  },
  "message": "Google Workspace DNS records created successfully",
  "timestamp": "2024-01-15T10:55:00Z"
}
```

---

## Error Handling

All endpoints return consistent error responses:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```

**Common Error Codes:**

- `MISSING_FIELDS`: Required fields are missing
- `INVALID_RECORD_TYPE`: Invalid DNS record type
- `INVALID_TTL`: TTL outside valid range (60-86400)
- `NO_UPDATE_FIELDS`: No fields provided for update
- `RECORD_CREATE_FAILED`: Failed to create record
- `RECORD_UPDATE_FAILED`: Failed to update record
- `RECORD_DELETE_FAILED`: Failed to delete record
- `RECORDS_RETRIEVAL_FAILED`: Failed to retrieve records
- `VALIDATION_FAILED`: Failed to validate records
- `RECOMMENDATIONS_FAILED`: Failed to retrieve recommendations
- `SETUP_FAILED`: Failed to setup Google Workspace DNS

---

## Audit Logging

All DNS operations are logged for audit purposes:

- **DNS Record Created**: `dns_record_created`
- **DNS Record Updated**: `dns_record_updated`
- **DNS Record Deleted**: `dns_record_deleted`
- **Google Workspace Setup**: `google_workspace_dns_setup`

Audit logs include:

- Admin user ID
- Admin role
- Action performed
- Resource ID
- Timestamp
- IP address
- User agent

---

## Rate Limiting

- **Read Operations**: 200 requests/minute
- **Write Operations**: 50 requests/minute

Rate limits are per-user and enforced at the middleware level.

---

## Security Considerations

1. **Authentication**: All endpoints require valid JWT token with admin role
2. **Authorization**: Permission checks ensure users can only perform allowed actions
3. **Audit Logging**: All operations are logged for compliance
4. **Input Validation**: All inputs are validated before processing
5. **Rate Limiting**: Prevents abuse and DoS attacks
6. **Error Handling**: Sensitive information is not exposed in error messages

---

## Integration with Cloudflare

The DNS API integrates with Cloudflare using:

- **API Token**: `CLOUDFLARE_API_TOKEN` environment variable
- **Zone ID**: `CLOUDFLARE_ZONE_ID` environment variable
- **Rate Limit Handling**: Automatic retry with exponential backoff
- **Caching**: 5-minute TTL for DNS records cache

---

## Database Schema

DNS records are stored in the `dns_records` table:

```sql
CREATE TABLE dns_records (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  provider VARCHAR(50) NOT NULL,
  provider_record_id VARCHAR(255),
  record_type VARCHAR(10) NOT NULL,
  name VARCHAR(255) NOT NULL,
  value TEXT NOT NULL,
  ttl INT DEFAULT 3600,
  priority INT,
  status VARCHAR(20),
  validation_status VARCHAR(20),
  validation_error TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by UUID REFERENCES users(id)
);
```

---

## Examples

### Create MX Record

```bash
curl -X POST https://api.cloudtolocalllm.online/api/admin/dns/records \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "recordType": "MX",
    "name": "mail.example.com",
    "value": "5 gmail-smtp-in.l.google.com",
    "ttl": 3600,
    "priority": 5
  }'
```

### List All DNS Records

```bash
curl -X GET https://api.cloudtolocalllm.online/api/admin/dns/records \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### Setup Google Workspace DNS

```bash
curl -X POST https://api.cloudtolocalllm.online/api/admin/dns/setup-google \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "cloudtolocalllm.online",
    "recordTypes": ["mx", "spf", "dmarc"]
  }'
```

---

## Related Documentation

- [Email Configuration API](./EMAIL_API.md)
- [Cloudflare DNS Service](../services/cloudflare-dns-service.js)
- [Admin Authentication](../middleware/admin-auth.js)
- [Audit Logging](../utils/audit-logger.js)
