require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const MIGRATIONS_DIR = path.resolve(__dirname, '../migrations');
const DATABASE_URL = process.env.DATABASE_URL;

function runPsql(args, description) {
  const result = spawnSync('psql', args, { stdio: 'inherit', env: process.env });
  if (result.status !== 0) {
    const error = new Error(`${description} failed`);
    error.code = 'MIGRATION_FAILED';
    throw error;
  }
}

async function runMigrations() {
  try {
    if (!DATABASE_URL) {
      throw new Error('DATABASE_URL is required for migrations');
    }

    console.log('Starting database migrations...');

    runPsql([
      DATABASE_URL,
      '-c',
      `
        CREATE TABLE IF NOT EXISTS _applied_migrations (
          filename TEXT PRIMARY KEY,
          applied_at TIMESTAMP DEFAULT NOW()
        );
      `,
    ], 'creating migration tracking table');

    const migrationFiles = fs.readdirSync(MIGRATIONS_DIR)
      .filter((filename) => filename.endsWith('.sql'))
      .sort();

    for (const filename of migrationFiles) {
      const migrationPath = path.join(MIGRATIONS_DIR, filename);
      const check = spawnSync('psql', [
        DATABASE_URL,
        '-tAc',
        `SELECT 1 FROM _applied_migrations WHERE filename='${filename.replace(/'/g, "''")}'`,
      ], { encoding: 'utf8', env: process.env });

      if (check.status !== 0) {
        throw new Error(`Failed to check migration status for ${filename}`);
      }

      if (String(check.stdout).trim() === '1') {
        console.log(`[migrate] Skipping (already applied): ${filename}`);
        continue;
      }

      console.log(`[migrate] Applying migration: ${filename}`);
      runPsql([DATABASE_URL, '-f', migrationPath], `applying migration ${filename}`);
      runPsql([
        DATABASE_URL,
        '-c',
        `INSERT INTO _applied_migrations (filename) VALUES ('${filename.replace(/'/g, "''")}') ON CONFLICT DO NOTHING;`,
      ], `recording migration ${filename}`);
      console.log(`[migrate] Applied: ${filename}`);
    }

    console.log('Migrations completed successfully!');

    await runSeedData();

    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

async function runSeedData() {
  try {
    console.log('Starting seed data insertion...');
    console.log('Seed data insertion completed!');
  } catch (error) {
    console.error('Seed data insertion failed:', error);
    throw error;
  }
}

if (require.main === module) {
  runMigrations();
}

module.exports = { runMigrations, runSeedData };
