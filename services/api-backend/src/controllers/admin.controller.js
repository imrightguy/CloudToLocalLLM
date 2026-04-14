const { db } = require('../database/connection');
const { sql } = require('drizzle-orm');
const { child } = require('../utils/logger');

const log = child({ controller: 'admin' });

const seedDemo = async (_req, res) => {
  try {
    const { seedDemoData } = require('../../scripts/seed-demo');
    await seedDemoData();

    return res.json({
      success: true,
      data: null,
      message: 'Demo data seeded successfully',
    });
  } catch (error) {
    log.error('Seed demo error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to seed demo data', code: 'SEED_FAILED' },
    });
  }
};

const clearDemo = async (_req, res) => {
  try {
    const tablesToClean = [
      'sms_logs', 'communication_logs', 'visits', 'leases',
      'leads', 'employee_schedules', 'employee_assignments',
      'units', 'employees', 'buildings',
    ];

    for (const table of tablesToClean) {
      try {
        await db.execute(sql`DELETE FROM ${sql.raw(table)}`);
      } catch {
        /* table may not exist */
      }
    }

    return res.json({
      success: true,
      data: null,
      message: 'Demo data cleared successfully',
    });
  } catch (error) {
    log.error('Clear demo error', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to clear demo data', code: 'CLEAR_FAILED' },
    });
  }
};

module.exports = { seedDemo, clearDemo };
