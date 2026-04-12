require('dotenv').config();
const { migrate } = require('drizzle-kit');
const { db } = require('../src/database/connection');

// Migration script for initializing the database
async function runMigrations() {
  try {
    console.log('Starting database migrations...');

    // Run drizzle-kit migrations
    await migrate(db, {
      migrationsFolder: './migrations',
    });

    console.log('Migrations completed successfully!');

    // Run initial seed data if needed
    await runSeedData();

    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

// Seed initial data
async function runSeedData() {
  try {
    console.log('Starting seed data insertion...');

    // Example: Insert initial data if needed
    // await db.insert(schema.buildings).values([/* initial buildings */]);
    // await db.insert(schema.schedules).values([/* initial schedules */]);

    console.log('Seed data insertion completed!');
  } catch (error) {
    console.error('Seed data insertion failed:', error);
    throw error;
  }
}

// If called directly, run migrations
if (require.main === module) {
  runMigrations();
}

module.exports = { runMigrations, runSeedData };
