require('dotenv').config();
const { connect } = require('../src/database/connection');

// Seed script for initial data
async function seedData() {
  try {
    console.log('Connecting to database...');
    await connect();

    console.log('Seeding initial data...');

    // Example seed data - remove these when implementing real migrations
    console.log('Seed data insertion completed!');

    process.exit(0);
  } catch (error) {
    console.error('Seed data insertion failed:', error);
    process.exit(1);
  }
}

// If called directly, run seeding
if (require.main === module) {
  seedData();
}

module.exports = { seedData };
