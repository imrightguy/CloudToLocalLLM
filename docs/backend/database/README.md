# Database Migrations

This directory contains database migration scripts for the Admin Center feature.

## Overview

Migrations are versioned SQL scripts that modify the database schema. Each migration has:

- A forward migration file (e.g., `001_admin_center_schema.sql`)
- A rollback file (e.g., `001_admin_center_schema_rollback.sql`)
- A tracking entry in the `schema_migrations` table

## Migration Files

### 001_admin_center_schema.sql

Creates the core admin center tables:

- `subscriptions` - User subscription information
- `payment_transactions` - Payment transaction records
- `payment_methods` - User payment method details
- `refunds` - Refund records
- `admin_roles` - Administrator role assignments
- `admin_audit_logs` - Audit trail of admin actions

## Usage

### Prerequisites

1. Ensure PostgreSQL is running and accessible
2. Set environment variables for database connection:

   ```bash
   export DATABASE_URL="postgresql://user:password@host:port/database"
   # OR
   export PGHOST=localhost
   export PGPORT=5432
   export PGDATABASE=CloudToLocalLLM
   export PGUSER=postgres
   export PGPASSWORD=yourpassword
   ```

3. Install dependencies (if not already installed):

   ```bash
   cd services/api-backend
   npm install
   ```

### Running Migrations

#### Apply a Migration

```bash
node services/api-backend/database/migrations/run-migration.js up 001
```

#### Rollback a Migration

```bash
node services/api-backend/database/migrations/run-migration.js down 001
```

#### Check Migration Status

```bash
node services/api-backend/database/migrations/run-migration.js status
```

### Manual Execution

You can also run migrations manually using `psql`:

#### Apply Migration

```bash
psql -h localhost -U postgres -d CloudToLocalLLM -f services/api-backend/database/migrations/001_admin_center_schema.sql
```

#### Rollback Migration

```bash
psql -h localhost -U postgres -d CloudToLocalLLM -f services/api-backend/database/migrations/001_admin_center_schema_rollback.sql
```

## Migration Tracking

The `schema_migrations` table tracks which migrations have been applied:

```sql
SELECT * FROM schema_migrations ORDER BY applied_at DESC;
```

Columns:

- `version` - Migration version (e.g., '001')
- `name` - Migration name
- `applied_at` - When the migration was applied
- `rolled_back_at` - When the migration was rolled back (NULL if still applied)

## Creating New Migrations

1. Create a new migration file with the next version number:

   ```
   002_feature_name.sql
   ```

2. Create a corresponding rollback file:

   ```
   002_feature_name_rollback.sql
   ```

3. Follow the existing migration structure:
   - Add comments explaining the changes
   - Use `IF NOT EXISTS` for idempotency
   - Create indexes for performance
   - Add triggers for `updated_at` columns
   - Include rollback logic in the rollback file

4. Test the migration:

   ```bash
   # Apply
   node run-migration.js up 002

   # Verify
   node run-migration.js status

   # Rollback (if needed)
   node run-migration.js down 002
   ```

## Best Practices

1. **Always use transactions** - The migration runner wraps each migration in a transaction
2. **Test rollbacks** - Always test that rollbacks work correctly
3. **Backup before production** - Always backup the database before running migrations in production
4. **Idempotent migrations** - Use `IF NOT EXISTS` and `IF EXISTS` to make migrations idempotent
5. **Document changes** - Add comments explaining what each migration does
6. **Version control** - Commit migration files to version control

## Troubleshooting

### Migration fails with "relation already exists"

The migration may have been partially applied. Check the database state and either:

- Manually clean up the partial migration
- Use the rollback script
- Make the migration idempotent with `IF NOT EXISTS`

### Cannot connect to database

Check your environment variables and ensure PostgreSQL is running:

```bash
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"
```

### Migration tracking table not found

Run the migration runner once to create the tracking table:

```bash
node run-migration.js status
```

## Production Deployment

For production deployments:

1. **Backup the database first**:

   ```bash
   pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **Test in staging environment** before production

3. **Run migrations during maintenance window** if possible

4. **Monitor the migration**:

   ```bash
   node run-migration.js up 001 2>&1 | tee migration.log
   ```

5. **Verify the migration**:

   ```bash
   node run-migration.js status
   psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "\dt"
   ```

6. **Have rollback plan ready** in case of issues

## Support

For issues or questions about migrations, refer to:

- Admin Center Design Document: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Database Schema: `services/api-backend/database/schema.pg.sql`
