#!/usr/bin/env node

/**
 * Database Migration Runner
 *
 * Usage:
 *   node run-migration.js up 001    - Apply migration 001
 *   node run-migration.js down 001  - Rollback migration 001
 *   node run-migration.js status    - Show migration status
 *
 * Environment Variables:
 *   DATABASE_URL - PostgreSQL connection string
 *   PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD - Individual connection params
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';

const { Pool } = pg;
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Database connection configuration
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  host: process.env.PGHOST || 'localhost',
  port: parseInt(process.env.PGPORT || '5432'),
  database: process.env.PGDATABASE || 'CloudToLocalLLM',
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD,
  ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Create migrations tracking table if it doesn't exist
async function ensureMigrationsTable() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        version TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        applied_at TIMESTAMPTZ DEFAULT NOW(),
        rolled_back_at TIMESTAMPTZ
      );
    `);
    console.log('✓ Migrations tracking table ready');
  } finally {
    client.release();
  }
}

// Apply a migration
async function applyMigration(version) {
  const client = await pool.connect();
  try {
    // Check if migration already applied
    const checkResult = await client.query(
      'SELECT * FROM schema_migrations WHERE version = $1 AND rolled_back_at IS NULL',
      [version],
    );

    if (checkResult.rows.length > 0) {
      console.log(`⚠ Migration ${version} already applied`);
      return;
    }

    // Read migration file - try to find the migration file with any name pattern
    let migrationPath;
    let migrationName = 'unknown';

    // For now, construct the path based on version
    // Version 001 -> 001_admin_center_schema.sql
    // Version 002 -> 002_webhook_events_table.sql
    // Version 003 -> 003_email_relay_dns_setup.sql
    if (version === '001') {
      migrationPath = join(__dirname, `${version}_admin_center_schema.sql`);
      migrationName = 'admin_center_schema';
    } else if (version === '002') {
      migrationPath = join(__dirname, `${version}_webhook_events_table.sql`);
      migrationName = 'webhook_events_table';
    } else if (version === '003') {
      migrationPath = join(__dirname, `${version}_email_relay_dns_setup.sql`);
      migrationName = 'email_relay_dns_setup';
    } else {
      // Generic pattern for future migrations
      migrationPath = join(__dirname, `${version}_*.sql`);
      migrationName = 'migration';
    }

    const migrationSQL = readFileSync(migrationPath, 'utf8');

    console.log(`Applying migration ${version}...`);

    // Begin transaction
    await client.query('BEGIN');

    try {
      // Execute migration
      await client.query(migrationSQL);

      // Record migration
      await client.query(
        'INSERT INTO schema_migrations (version, name) VALUES ($1, $2)',
        [version, migrationName],
      );

      // Commit transaction
      await client.query('COMMIT');
      console.log(`✓ Migration ${version} applied successfully`);
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error(`✗ Failed to apply migration ${version}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Rollback a migration
async function rollbackMigration(version) {
  const client = await pool.connect();
  try {
    // Check if migration is applied
    const checkResult = await client.query(
      'SELECT * FROM schema_migrations WHERE version = $1 AND rolled_back_at IS NULL',
      [version],
    );

    if (checkResult.rows.length === 0) {
      console.log(`⚠ Migration ${version} not applied or already rolled back`);
      return;
    }

    // Read rollback file - try to find the rollback file with any name pattern
    let rollbackPath;

    // Construct the rollback path based on version
    if (version === '001') {
      rollbackPath = join(
        __dirname,
        `${version}_admin_center_schema_rollback.sql`,
      );
    } else if (version === '002') {
      rollbackPath = join(
        __dirname,
        `${version}_webhook_events_table_rollback.sql`,
      );
    } else if (version === '003') {
      rollbackPath = join(
        __dirname,
        `${version}_email_relay_dns_setup_rollback.sql`,
      );
    } else {
      // Generic pattern for future migrations
      rollbackPath = join(__dirname, `${version}_*_rollback.sql`);
    }

    const rollbackSQL = readFileSync(rollbackPath, 'utf8');

    console.log(`Rolling back migration ${version}...`);

    // Begin transaction
    await client.query('BEGIN');

    try {
      // Execute rollback
      await client.query(rollbackSQL);

      // Update migration record
      await client.query(
        'UPDATE schema_migrations SET rolled_back_at = NOW() WHERE version = $1',
        [version],
      );

      // Commit transaction
      await client.query('COMMIT');
      console.log(`✓ Migration ${version} rolled back successfully`);
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error(`✗ Failed to rollback migration ${version}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Show migration status
async function showStatus() {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT version, name, applied_at, rolled_back_at
      FROM schema_migrations
      ORDER BY applied_at DESC
    `);

    console.log('\nMigration Status:');
    console.log('─'.repeat(80));

    if (result.rows.length === 0) {
      console.log('No migrations applied yet');
    } else {
      result.rows.forEach((row) => {
        const status = row.rolled_back_at ? '✗ ROLLED BACK' : '✓ APPLIED';
        const date = row.rolled_back_at || row.applied_at;
        console.log(
          `${status} | ${row.version} | ${row.name} | ${date.toISOString()}`,
        );
      });
    }

    console.log('─'.repeat(80));
  } finally {
    client.release();
  }
}

// Main execution
async function main() {
  const [, , command, version] = process.argv;

  if (!command) {
    console.log('Usage:');
    console.log('  node run-migration.js up <version>    - Apply migration');
    console.log('  node run-migration.js down <version>  - Rollback migration');
    console.log(
      '  node run-migration.js status          - Show migration status',
    );
    process.exit(1);
  }

  try {
    await ensureMigrationsTable();

    switch (command) {
      case 'up':
        if (!version) {
          console.error('Error: Version required for "up" command');
          process.exit(1);
        }
        await applyMigration(version);
        break;

      case 'down':
        if (!version) {
          console.error('Error: Version required for "down" command');
          process.exit(1);
        }
        await rollbackMigration(version);
        break;

      case 'status':
        await showStatus();
        break;

      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
