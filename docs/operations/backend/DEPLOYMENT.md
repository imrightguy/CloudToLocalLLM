# Zoidbot API Backend Deployment Guide

## PostgreSQL Migration & Cloud Run Deployment

This guide covers the complete deployment process for migrating from SQLite to PostgreSQL and deploying to Google Cloud Run.

## Prerequisites

- Google Cloud SDK installed and authenticated
- Project ID: `zoidbot-468303`
- Required APIs enabled:
  - Cloud SQL Admin API
  - Cloud Run API
  - Cloud Build API
  - Container Registry API

## Quick Start

### 1. Set Up Cloud SQL PostgreSQL

```bash
cd services/api-backend

# Make scripts executable
chmod +x scripts/*.sh

# Create Cloud SQL PostgreSQL instance
npm run db:setup-cloud-sql
```

This will:

- Create a PostgreSQL 15 instance named `zoidbot-db`
- Create the `zoidbot` database
- Create an `appuser` with a secure password
- Generate `cloud-sql-config.env` with connection details

### 2. Deploy to Cloud Run

```bash
# Deploy with PostgreSQL configuration
npm run deploy:cloud-run
```

This will:

- Build and push the container image
- Deploy to Cloud Run with PostgreSQL environment variables
- Configure Cloud SQL connection
- Test the deployment

### 3. Verify Deployment

```bash
# Test database connectivity
npm run db:test

# Test authentication flow
SERVICE_URL="https://your-service-url" npm run test:auth-flow

# Check health endpoint
curl https://your-service-url/api/db/health
```

## Manual Deployment Steps

### Step 1: Cloud SQL Setup

```bash
# Set project
gcloud config set project zoidbot-468303

# Create PostgreSQL instance
gcloud sql instances create zoidbot-db \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --storage-type=SSD \
    --storage-size=10GB \
    --backup-start-time=03:00

# Create database
gcloud sql databases create zoidbot --instance=zoidbot-db

# Create user
gcloud sql users create appuser \
    --instance=zoidbot-db \
    --password=<SECURE_PASSWORD>
```

### Step 2: Environment Configuration

Copy `.env.production.template` to `.env.production` and fill in values:

```bash
cp .env.production.template .env.production
# Edit .env.production with your actual values
```

Required environment variables:

- `DB_TYPE=postgresql`
- `DB_NAME=zoidbot`
- `DB_USER=appuser`
- `DB_PASSWORD=<your-password>`
- `DB_HOST=/cloudsql/zoidbot-468303:us-central1:zoidbot-db`
- `SUPABASE_AUTH_DOMAIN=dev-v2f2p008x3dr74ww.us.auth0.com`
- `SUPABASE_AUTH_AUDIENCE=https://api.zoidbot.online`

### Step 3: Build and Deploy

```bash
# Build container image
gcloud builds submit --tag gcr.io/zoidbot-468303/zoidbot-api

# Deploy to Cloud Run
gcloud run deploy zoidbot-api \
    --image gcr.io/zoidbot-468303/zoidbot-api \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --memory 1Gi \
    --set-env-vars "NODE_ENV=production,DB_TYPE=postgresql,SUPABASE_AUTH_DOMAIN=dev-v2f2p008x3dr74ww.us.auth0.com,SUPABASE_AUTH_AUDIENCE=https://api.zoidbot.online" \
    --add-cloudsql-instances zoidbot-468303:us-central1:zoidbot-db
```

## Testing

### Database Testing

```bash
# Test database connectivity and schema
npm run db:test
```

### Authentication Flow Testing

```bash
# Basic testing (no authentication)
SERVICE_URL="https://your-service-url" npm run test:auth-flow

# With authentication token
TEST_TOKEN="your-auth0-jwt-token" SERVICE_URL="https://your-service-url" npm run test:auth-flow
```

### Health Checks

```bash
# Database health
curl https://your-service-url/api/db/health

# Expected response:
{
  "status": "healthy",
  "database_type": "postgresql",
  "schema_validation": {
    "user_sessions_table": true,
    "tunnel_connections_table": true,
    "audit_logs_table": true,
    "schema_migrations_table": true
  },
  "all_tables_valid": true,
  "timestamp": "2025-01-09T..."
}
```

## Monitoring

### Cloud Run Logs

```bash
# View logs
gcloud logs tail --service=zoidbot-api

# Filter for database logs
gcloud logs tail --service=zoidbot-api --filter="database"

# Filter for authentication logs
gcloud logs tail --service=zoidbot-api --filter="auth"
```

### Cloud SQL Monitoring

```bash
# Check Cloud SQL instance status
gcloud sql instances describe zoidbot-db

# View Cloud SQL logs
gcloud logging read "resource.type=cloudsql_database"
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**

   ```
   Error: Failed to connect to PostgreSQL
   ```

   - Check Cloud SQL instance is running
   - Verify environment variables
   - Ensure service account has Cloud SQL Client role

2. **Schema Validation Failed**

   ```
   Error: Database schema validation failed
   ```

   - Run `npm run db:test` to see specific table issues
   - Check migration logs in Cloud Run

3. **Authentication Errors**

   ```
   Error: Authentication service not available
   ```

   - Verify `SUPABASE_AUTH_DOMAIN` and `SUPABASE_AUTH_AUDIENCE` environment variables
   - Check Auth0 JWT validation configuration

### Service Account Permissions

Ensure your Cloud Run service account has:

- `roles/cloudsql.client` - For Cloud SQL access
- Auth0 JWT validation (configured via environment variables)

### Performance Tuning

For production workloads, consider:

- Upgrading Cloud SQL tier (from `db-f1-micro`)
- Adjusting connection pool settings
- Enabling Cloud SQL Insights for monitoring
- Setting up read replicas for high availability

## Rollback Plan

If issues occur, rollback to SQLite:

1. Set `DB_TYPE=sqlite` in Cloud Run environment
2. Redeploy the service
3. The application will automatically use SQLite migrator

## Security Considerations

- Database passwords are stored in Cloud Run environment variables
- Consider using Google Secret Manager for sensitive values
- Regularly rotate database passwords
- Monitor Cloud SQL access logs
- Use least-privilege service account permissions

## Cost Optimization

- Start with `db-f1-micro` tier and scale up as needed
- Enable automatic storage increases
- Set up billing alerts
- Consider committed use discounts for predictable workloads
