# Database Setup Quickstart

Quick reference for setting up the Admin Center database schema and test data.

## Prerequisites

1. PostgreSQL 12+ installed and running
2. Node.js 18+ installed
3. Database created: `CloudToLocalLLM`
4. Environment variables configured

## Environment Setup

```bash
# Option 1: Using DATABASE_URL
export DATABASE_URL="postgresql://postgres:password@localhost:5432/CloudToLocalLLM"

# Option 2: Using individual variables
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=CloudToLocalLLM
export PGUSER=postgres
export PGPASSWORD=yourpassword

# For development
export NODE_ENV=development
```

## Quick Setup (Development)

```bash
# 1. Navigate to the project root
cd /path/to/CloudToLocalLLM

# 2. Install dependencies (if not already done)
cd services/api-backend
npm install

# 3. Apply base schema (if not already applied)
psql -h localhost -U postgres -d CloudToLocalLLM -f database/schema.pg.sql

# 4. Apply admin center migration
node database/migrations/run-migration.js up 001

# 5. Apply seed data (development only)
node database/seeds/run-seed.js apply 001

# 6. Verify setup
node database/seeds/run-seed.js apply 001 | tail -10
```

## Common Commands

### Migrations

```bash
# Check migration status
node database/migrations/run-migration.js status

# Apply migration
node database/migrations/run-migration.js up 001

# Rollback migration
node database/migrations/run-migration.js down 001
```

### Seed Data (Development Only)

```bash
# Apply seed data
node database/seeds/run-seed.js apply 001

# Clean seed data
node database/seeds/run-seed.js clean
```

### Manual SQL Execution

```bash
# Apply migration manually
psql -h localhost -U postgres -d CloudToLocalLLM -f database/migrations/001_admin_center_schema.sql

# Apply seed data manually
psql -h localhost -U postgres -d CloudToLocalLLM -f database/seeds/001_admin_center_dev_data.sql

# Rollback migration manually
psql -h localhost -U postgres -d CloudToLocalLLM -f database/migrations/001_admin_center_schema_rollback.sql
```

## Verification Queries

```bash
# Check tables exist
psql -h localhost -U postgres -d CloudToLocalLLM -c "\dt"

# Check admin center tables
psql -h localhost -U postgres -d CloudToLocalLLM -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('subscriptions', 'payment_transactions', 'payment_methods', 'refunds', 'admin_roles', 'admin_audit_logs');"

# Check test data
psql -h localhost -U postgres -d CloudToLocalLLM -c "SELECT COUNT(*) as test_users FROM users WHERE email LIKE 'test.%@example.com';"

# Check admin roles
psql -h localhost -U postgres -d CloudToLocalLLM -c "SELECT u.email, ar.role, ar.is_active FROM admin_roles ar JOIN users u ON ar.user_id = u.id;"
```

## Reset Database (Development)

```bash
# Complete reset
node database/seeds/run-seed.js clean
node database/migrations/run-migration.js down 001
node database/migrations/run-migration.js up 001
node database/seeds/run-seed.js apply 001
```

## Production Deployment

```bash
# 1. Backup database first!
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Apply migration only (NO seed data in production!)
node database/migrations/run-migration.js up 001

# 3. Verify migration
node database/migrations/run-migration.js status

# 4. Verify tables
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "\dt"
```

## Troubleshooting

### Connection Issues

```bash
# Test connection
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"

# Check environment variables
echo $DATABASE_URL
echo $PGHOST $PGPORT $PGDATABASE $PGUSER
```

### Migration Already Applied

```bash
# Check status
node database/migrations/run-migration.js status

# If needed, rollback and reapply
node database/migrations/run-migration.js down 001
node database/migrations/run-migration.js up 001
```

### Seed Data Already Exists

```bash
# Clean and reapply
node database/seeds/run-seed.js clean
node database/seeds/run-seed.js apply 001
```

## File Structure

```
services/api-backend/database/
├── schema.pg.sql                           # Base schema
├── migrations/
│   ├── README.md                           # Migration documentation
│   ├── run-migration.js                    # Migration runner
│   ├── 001_admin_center_schema.sql         # Admin center migration
│   └── 001_admin_center_schema_rollback.sql # Rollback script
└── seeds/
    ├── README.md                           # Seed documentation
    ├── run-seed.js                         # Seed runner
    └── 001_admin_center_dev_data.sql       # Test data
```

## Next Steps

After setting up the database:

1. **Backend API**: Implement admin authentication middleware (Task 2.1)
2. **Frontend Models**: Create Dart models for subscriptions, payments, etc. (Task 11)
3. **Payment Gateway**: Set up Stripe SDK integration (Task 4.1)

## Documentation

- Migrations: `services/api-backend/database/migrations/README.md`
- Seed Data: `services/api-backend/database/seeds/README.md`
- Admin Center Design: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Admin Center Tasks: `.kiro/specs/admin-center/tasks.md`
