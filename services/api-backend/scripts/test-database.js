#!/usr/bin/env node

/**
 * Database Testing Script for CloudToLocalLLM PostgreSQL
 * Tests database connectivity, schema validation, and basic operations
 */

import { DatabaseMigratorPG } from '../database/migrate-pg.js';
import dotenv from 'dotenv';

dotenv.config();

async function testDatabase() {
  console.log(' CloudToLocalLLM Database Testing Script');
  console.log('==========================================\n');

  const dbType = process.env.DB_TYPE || 'postgresql';
  console.log(` Database Type: ${dbType}`);

  if (dbType !== 'postgresql') {
    console.warn(
      ' WARNING: DB_TYPE is not set to postgresql, but this project now exclusively uses PostgreSQL.',
    );
  }

  let migrator;
  try {
    console.log('🚀 Initializing PostgreSQL migrator...');
    migrator = new DatabaseMigratorPG();

    // Test 1: Connection
    console.log('\n📡 Test 1: Database Connection');
    console.log('------------------------------');
    await migrator.initialize();
    console.log(' ✅ Connection successful');

    // Test 2: Migrations Table
    console.log('\n📊 Test 2: Migrations Table Creation');
    console.log('------------------------------------');
    await migrator.createMigrationsTable();
    console.log(' ✅ Migrations table ready');

    // Test 3: Schema Application
    console.log('\n🏗️  Test 3: Schema Application');
    console.log('-----------------------------');
    await migrator.applyInitialSchema();
    console.log(' ✅ Schema applied successfully');

    // Test 4: Schema Validation
    console.log('\n🔍 Test 4: Schema Validation');
    console.log('----------------------------');
    const validation = await migrator.validateSchema();
    console.log('Validation Results:');
    Object.entries(validation.results).forEach(([table, valid]) => {
      console.log(
        `  ${valid ? '✅' : '❌'} ${table}: ${valid ? 'EXISTS' : 'MISSING'}`,
      );
    });
    console.log(
      `\n Overall Status: ${validation.allValid ? '✅ VALID' : '❌ INVALID'}`,
    );

    // Test 5: Applied Migrations
    console.log('\n📜 Test 5: Applied Migrations');
    console.log('-----------------------------');
    const migrations = await migrator.getAppliedMigrations();
    if (migrations.length > 0) {
      console.log('Applied migrations:');
      migrations.forEach((m) => {
        console.log(`   ${m.version}: ${m.name} (${m.applied_at})`);
      });
    } else {
      console.log('    No migrations applied yet');
    }

    // Test 6: Basic Operations
    console.log('\n⚡ Test 6: Basic PostgreSQL Operations');
    console.log('-------------------------------------');

    // Test UUID generation
    const { rows: uuidTest } = await migrator.pool.query(
      'SELECT gen_random_uuid() as test_uuid',
    );
    console.log(` ✅ UUID generation: ${uuidTest[0].test_uuid}`);

    // Test JSONB operations
    const { rows: jsonTest } = await migrator.pool.query(
      'SELECT \'{"test": true}\'::jsonb as test_json',
    );
    console.log(` ✅ JSONB support: ${JSON.stringify(jsonTest[0].test_json)}`);

    // Test table counts
    const tables = [
      'user_sessions',
      'tunnel_connections',
      'audit_logs',
      'api_usage',
    ];
    for (const table of tables) {
      try {
        const { rows } = await migrator.pool.query(
          `SELECT COUNT(*) as count FROM ${table}`,
        );
        console.log(` ✅ ${table}: ${rows[0].count} records`);
      } catch (e) {
        console.log(` ❌ ${table}: ${e.message}`);
      }
    }

    console.log('\n✨ All database tests completed successfully!');
    console.log('\n📊 Summary:');
    console.log(`  Database Type: ${dbType}`);
    console.log('  Connection:  Working');
    console.log(`  Schema: ${validation.allValid ? '✅ Valid' : '❌ Invalid'}`);
    console.log(`  Migrations: ${migrations.length} applied`);
  } catch (error) {
    console.error('\n❌ Database test failed:');
    console.error(error.message);
    console.error('\n🛠️ Troubleshooting:');

    console.error('  1. Check PostgreSQL instance is running');
    console.error(
      '  2. Verify environment variables: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD',
    );
    console.error('  3. Check database connectivity and permissions');

    process.exit(1);
  } finally {
    if (migrator) {
      await migrator.close();
      console.log('\n👋 Database connection closed');
    }
  }
}

// Run the tests
testDatabase().catch(console.error);
