// Initialize Tunnel System
let authService = null;
let dbMigrator = null;
let authDbMigrator = null;

async function initializeTunnelSystem(retries = 10) {
  console.log('DEBUG: Starting initializeTunnelSystem function');
  logger.info('Starting initialization of tunnel system...');
  try {
    console.log('DEBUG: About to initialize database pool');
    // Initialize centralized database connection pool (Requirement 17)
    logger.info('Initializing centralized database connection pool...');
    initializePool();
    console.log('DEBUG: Database pool initialization completed');
    logger.info('Database connection pool initialized successfully');

    // Initialize application database
    dbMigrator = new DatabaseMigratorPG();

    // Add retry logic for THE ENTIRE database startup sequence
    let connected = false;
    let attempt = 0;
    while (!connected && attempt < retries) {
      try {
        attempt++;
        logger.info(`Database initialization attempt ${attempt}/${retries}...`);
        
        await dbMigrator.initialize();
        await dbMigrator.createMigrationsTable();
        await dbMigrator.applyInitialSchema();
        
        console.log('DEBUG: About to run migrations');
        await dbMigrator.migrate();
        
        console.log('DEBUG: Validating database schema');
        const validation = await dbMigrator.validateSchema();
        if (!validation.allValid) {
          throw new Error('Database schema validation failed');
        }
        
        connected = true;
        logger.info('Database system fully initialized and migrated');
      } catch (err) {
        if (attempt >= retries) throw err;
        logger.warn(`Database initialization attempt ${attempt} failed: ${err.message}. Retrying in 5s...`);
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }

    // Set dbMigrator for health endpoint now that it's initialized
    setDbMigrator(dbMigrator);

    // Register database with health check service
    healthCheckService.registerDatabase(dbMigrator);
    logger.info('Database registered with health check service');

    // Start database pool monitoring (Requirement 17)
    logger.info('Starting database pool monitoring...');
    startMonitoring();
    logger.info('Database pool monitoring started successfully');
