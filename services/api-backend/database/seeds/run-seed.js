#!/usr/bin/env node

/**
 * Database Seed Runner
 *
 * Usage:
 *   node run-seed.js apply 001    - Apply seed data
 *   node run-seed.js clean        - Remove all seed data
 *
 * Environment Variables:
 *   DATABASE_URL - PostgreSQL connection string
 *   PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD - Individual connection params
 *
 * WARNING: This script is for DEVELOPMENT ONLY. Do not run in production!
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
  database: process.env.PGDATABASE || 'zoidbot',
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD,
  ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : false,
});

// Apply seed data
async function applySeed(version) {
  const client = await pool.connect();
  try {
    // Read seed file
    const seedPath = join(__dirname, `${version}_admin_center_dev_data.sql`);
    const seedSQL = readFileSync(seedPath, 'utf8');

    console.log(`Applying seed data ${version}...`);
    console.log('⚠️  WARNING: This will insert test data into the database');

    // Begin transaction
    await client.query('BEGIN');

    try {
      // Execute seed
      await client.query(seedSQL);

      // Commit transaction
      await client.query('COMMIT');
      console.log(`✓ Seed data ${version} applied successfully`);

      // Show summary
      const summary = await client.query(`
        SELECT 
          'Users' as entity, COUNT(*) as count FROM users WHERE email LIKE 'test.%@example.com'
        UNION ALL
        SELECT 'Subscriptions', COUNT(*) FROM subscriptions
        UNION ALL
        SELECT 'Transactions', COUNT(*) FROM payment_transactions
        UNION ALL
        SELECT 'Payment Methods', COUNT(*) FROM payment_methods
        UNION ALL
        SELECT 'Refunds', COUNT(*) FROM refunds
        UNION ALL
        SELECT 'Admin Roles', COUNT(*) FROM admin_roles
        UNION ALL
        SELECT 'Audit Logs', COUNT(*) FROM admin_audit_logs
      `);

      console.log('\nDatabase Summary:');
      console.log('─'.repeat(40));
      summary.rows.forEach((row) => {
        console.log(`${row.entity.padEnd(20)} ${row.count}`);
      });
      console.log('─'.repeat(40));
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error(`✗ Failed to apply seed data ${version}:`, error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Clean seed data
async function cleanSeedData() {
  const client = await pool.connect();
  try {
    console.log('Cleaning seed data...');
    console.log(
      '⚠️  WARNING: This will delete all test data from the database',
    );

    // Begin transaction
    await client.query('BEGIN');

    try {
      // Delete in reverse order of dependencies
      console.log('  Deleting admin audit logs...');
      await client.query(`DELETE FROM admin_audit_logs WHERE admin_user_id IN (
        SELECT id FROM users WHERE email LIKE 'test.%@example.com' OR email = 'cmaltais@zoidbot.online'
      )`);

      console.log('  Deleting admin roles...');
      await client.query(`DELETE FROM admin_roles WHERE user_id IN (
        SELECT id FROM users WHERE email LIKE 'test.%@example.com'
      )`);

      console.log('  Deleting refunds...');
      await client.query(`DELETE FROM refunds WHERE transaction_id IN (
        SELECT id FROM payment_transactions WHERE user_id IN (
          SELECT id FROM users WHERE email LIKE 'test.%@example.com'
        )
      )`);

      console.log('  Deleting payment methods...');
      await client.query(`DELETE FROM payment_methods WHERE user_id IN (
        SELECT id FROM users WHERE email LIKE 'test.%@example.com'
      )`);

      console.log('  Deleting payment transactions...');
      await client.query(`DELETE FROM payment_transactions WHERE user_id IN (
        SELECT id FROM users WHERE email LIKE 'test.%@example.com'
      )`);

      console.log('  Deleting subscriptions...');
      await client.query(`DELETE FROM subscriptions WHERE user_id IN (
        SELECT id FROM users WHERE email LIKE 'test.%@example.com'
      )`);

      console.log('  Deleting test users...');
      await client.query(
        "DELETE FROM users WHERE email LIKE 'test.%@example.com'",
      );

      // Commit transaction
      await client.query('COMMIT');
      console.log('✓ Seed data cleaned successfully');
    } catch (error) {
      // Rollback on error
      await client.query('ROLLBACK');
      throw error;
    }
  } catch (error) {
    console.error('✗ Failed to clean seed data:', error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Main execution
async function main() {
  const [, , command, version] = process.argv;

  if (!command) {
    console.log('Usage:');
    console.log('  node run-seed.js apply <version>  - Apply seed data');
    console.log('  node run-seed.js clean            - Remove all seed data');
    console.log('');
    console.log('WARNING: This script is for DEVELOPMENT ONLY!');
    process.exit(1);
  }

  // Check if we're in production
  if (process.env.NODE_ENV === 'production') {
    console.error('ERROR: Cannot run seed scripts in production environment!');
    process.exit(1);
  }

  try {
    switch (command) {
      case 'apply':
        if (!version) {
          console.error('Error: Version required for "apply" command');
          process.exit(1);
        }
        await applySeed(version);
        break;

      case 'clean':
        await cleanSeedData();
        break;

      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('Seed operation failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
