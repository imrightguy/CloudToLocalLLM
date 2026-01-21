import logger from '../logger.js';

let dbMigrator;

export function setDbMigrator(migrator) {
  dbMigrator = migrator;
}

export const dbHealthHandler = async (req, res) => {
  try {
    if (!dbMigrator) {
      return res.status(503).json({
        status: 'error',
        message: 'Database migrator not initialized',
        timestamp: new Date().toISOString(),
      });
    }

    // Perform a simple health check
    const validation = await dbMigrator.validateSchema();
    const dbType = process.env.DB_TYPE || 'postgresql';

    res.json({
      status: validation.allValid ? 'healthy' : 'degraded',
      database_type: dbType,
      schema_validation: validation.results,
      all_tables_valid: validation.allValid,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Database health check failed:', error);
    res.status(503).json({
      status: 'error',
      message: 'Database health check failed',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
};

export default dbHealthHandler;
