# Database Seed Data

This directory contains seed data scripts for populating the database with test data for development and testing purposes.

## ⚠️ WARNING

**These scripts are for DEVELOPMENT ONLY. Never run seed scripts in production!**

The seed runner includes safety checks to prevent execution in production environments.

## Overview

Seed scripts populate the database with realistic test data including:

- Test users with different subscription tiers
- Sample payment transactions
- Payment methods
- Refunds
- Admin roles
- Audit log entries

## Seed Files

### 001_admin_center_dev_data.sql

Creates comprehensive test data for the admin center:

- **5 test users**: free, premium, enterprise, trial, and canceled subscription users
- **5 subscriptions**: various tiers and statuses
- **5 payment transactions**: succeeded, failed, pending, and refunded
- **3 payment methods**: active and expired cards
- **1 refund**: sample refund record
- **3 admin roles**: super admin, support admin, finance admin
- **3 audit logs**: sample administrative actions

## Usage

### Prerequisites

1. Ensure the database migrations have been applied first:

   ```bash
   node services/api-backend/database/migrations/run-migration.js up 001
   ```

2. Set environment variables for database connection:

   ```bash
   export DATABASE_URL="postgresql://user:password@host:port/database"
   # OR
   export PGHOST=localhost
   export PGPORT=5432
   export PGDATABASE=zoidbot
   export PGUSER=postgres
   export PGPASSWORD=yourpassword
   ```

3. Ensure you're NOT in production:

   ```bash
   export NODE_ENV=development
   ```

### Applying Seed Data

```bash
node services/api-backend/database/seeds/run-seed.js apply 001
```

This will:

- Insert all test data
- Display a summary of inserted records
- Run in a transaction (rollback on error)

### Cleaning Seed Data

To remove all test data:

```bash
node services/api-backend/database/seeds/run-seed.js clean
```

This will:

- Delete all test users (email like 'test.%@example.com')
- Delete all related subscriptions, transactions, and audit logs
- Run in a transaction (rollback on error)

### Manual Execution

You can also run seed scripts manually using `psql`:

```bash
psql -h localhost -U postgres -d zoidbot -f services/api-backend/database/seeds/001_admin_center_dev_data.sql
```

## Test Data Details

### Test Users

| Email                       | Subscription Tier | Status   | Purpose                     |
| --------------------------- | ----------------- | -------- | --------------------------- |
| test.free@example.com       | Free              | Active   | Test free tier features     |
| test.premium@example.com    | Premium           | Active   | Test premium features       |
| test.enterprise@example.com | Enterprise        | Active   | Test enterprise features    |
| test.trial@example.com      | Premium           | Trialing | Test trial period           |
| test.canceled@example.com   | Premium           | Canceled | Test canceled subscriptions |

### Test Admin Users

| Email                           | Role          | Purpose                        |
| ------------------------------- | ------------- | ------------------------------ |
| cmaltais@zoidbot.online | Super Admin   | Full admin access              |
| test.support@example.com        | Support Admin | Test support admin permissions |
| test.finance@example.com        | Finance Admin | Test finance admin permissions |

### Test Payment Transactions

- **Successful payments**: Premium and Enterprise subscriptions
- **Failed payment**: Card declined scenario
- **Pending payment**: Payment in progress
- **Refunded payment**: Completed refund

### Test Payment Methods

- **Active Visa**: Premium user (4242)
- **Active Mastercard**: Enterprise user (5555)
- **Expired Visa**: Canceled user (1234)

## Verification

After applying seed data, verify the results:

```bash
# Check test users
psql -h localhost -U postgres -d zoidbot -c "SELECT email, name FROM users WHERE email LIKE 'test.%@example.com';"

# Check subscriptions
psql -h localhost -U postgres -d zoidbot -c "SELECT u.email, s.tier, s.status FROM subscriptions s JOIN users u ON s.user_id = u.id WHERE u.email LIKE 'test.%@example.com';"

# Check transactions
psql -h localhost -U postgres -d zoidbot -c "SELECT u.email, pt.amount, pt.status FROM payment_transactions pt JOIN users u ON pt.user_id = u.id WHERE u.email LIKE 'test.%@example.com';"

# Check admin roles
psql -h localhost -U postgres -d zoidbot -c "SELECT u.email, ar.role, ar.is_active FROM admin_roles ar JOIN users u ON ar.user_id = u.id;"
```

## Development Workflow

### Initial Setup

```bash
# 1. Apply migrations
node services/api-backend/database/migrations/run-migration.js up 001

# 2. Apply seed data
node services/api-backend/database/seeds/run-seed.js apply 001

# 3. Verify data
node services/api-backend/database/seeds/run-seed.js apply 001 | grep "Database Summary" -A 10
```

### Reset Database

```bash
# 1. Clean seed data
node services/api-backend/database/seeds/run-seed.js clean

# 2. Rollback migrations
node services/api-backend/database/migrations/run-migration.js down 001

# 3. Reapply migrations
node services/api-backend/database/migrations/run-migration.js up 001

# 4. Reapply seed data
node services/api-backend/database/seeds/run-seed.js apply 001
```

### Update Seed Data

```bash
# 1. Clean existing seed data
node services/api-backend/database/seeds/run-seed.js clean

# 2. Apply updated seed data
node services/api-backend/database/seeds/run-seed.js apply 001
```

## Creating New Seed Files

1. Create a new seed file with the next version number:

   ```
   002_feature_name_data.sql
   ```

2. Follow the existing seed structure:
   - Use `ON CONFLICT ... DO NOTHING` for idempotency
   - Insert data in order of dependencies
   - Include comments explaining the test data
   - Add a summary query at the end

3. Update the seed runner if needed to handle the new seed file

4. Test the seed script:

   ```bash
   node run-seed.js apply 002
   node run-seed.js clean
   ```

## Best Practices

1. **Always use test email domains** - Use 'test.%@example.com' pattern
2. **Use realistic data** - Make test data representative of real usage
3. **Document test scenarios** - Explain what each test user/data represents
4. **Keep it idempotent** - Use `ON CONFLICT` clauses
5. **Clean up after testing** - Run `clean` command when done
6. **Never run in production** - The script prevents this, but be careful

## Troubleshooting

### Seed fails with "foreign key violation"

Ensure migrations are applied first:

```bash
node services/api-backend/database/migrations/run-migration.js status
```

### Seed fails with "duplicate key value"

The seed data may already exist. Clean and reapply:

```bash
node run-seed.js clean
node run-seed.js apply 001
```

### Cannot connect to database

Check your environment variables and ensure PostgreSQL is running:

```bash
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"
```

### Production safety check fails

This is intentional! Never run seed scripts in production. If you need test data in staging, ensure `NODE_ENV` is not set to 'production'.

## Support

For issues or questions about seed data, refer to:

- Admin Center Design Document: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Migration Documentation: `services/api-backend/database/migrations/README.md`
